#!/usr/bin/env python3
"""tools/build-fonts.py — the desktop's own face, Sumi UI, from a classic Japanese dot font.

    python3 tools/build-fonts.py ui SHINONOME14.ttf COZETTEVECTOR.ttf

Writes (committed, so an install needs neither the sources nor Python's fontTools; setup.sh
puts it in /usr/local/share/fonts/fedokawaii, for every account — the login screen too):
    system/fonts/SumiUI.ttf     "Sumi UI": bar, panels, menus, launcher, notices, lock and
        login — 東雲 (Shinonome) Gothic 14, the regular weight (every stroke one pixel): a 14 px
        em, a 7 px cell (a kanji or kana 14), capitals 10 px tall (docs/design-system.md §2);
        and the air tables of configs/home/.config/fedokawaii/width.sh, measured from it
(The terminal's face, Sumi Term, is UDEV Gothic NF as it comes: lib/upstream.sh.)

It is drawn for its one size and nothing else: every pixel of the source becomes one square
of the outline, 100 units a pixel, so at 14 px — and at its whole multiples — each lands on
one screen pixel (never smoothed: system/60-fedokawaii-pixel.conf). The sources, read here
pixel by pixel at their own size:
    https://ftp.iij.ad.jp/pub/osdn.jp/users/8/8542/jfdotfont-20150527.zip
        8e574faaaa7e27294aec66464aaf427447b2f0ccec8fe00c50e69bbf509f14b1
        → JF-Dot-Shinonome14.ttf (public domain, as the Shinonome font it draws)
    https://github.com/the-moonwitch/Cozette/releases/tag/v.1.30.0 → CozetteVector.ttf
        2d54a586f824f32d9d2dd01ec3b990c2a4d6445efa77e20177efe382ebe51627 (MIT, © 2020 Ines)

What Sumi UI takes from where:
  · its letters, digits and signs (ASCII), the Latin-1 letters it draws one cell wide, every
    wide character (kanji, kana, the full-width forms), the half-width kana — the face's own;
  · five ASCII signs the face draws the old Japanese way (~ \\ ' " `): redrawn for code;
  · Latin Extended-A (ā č ę ł ő ř ş ž …): composed from the face's own letters and accents
    (its capitals made a row shorter for a mark, as it makes them for its own É);
  · the desktop's signs and the common punctuation (‘ ’ “ ” – — … • → ◆ ● ✓ ° ± × ÷ € …):
    drawn for it, art/signs.txt;
  · what else a line of text may hold, one cell wide (Greek, Cyrillic, the rest of the
    signs, arrows, shapes and lines): Cozette's 6 × 13 drawing, on the face's baseline.
So a character is one cell exactly when the terminal and kawa-panel count it as one (East
Asian width W and F: two; every other: one), and nothing reaches into the next cell.

Needs: python3-fonttools, python3-pillow.
"""
import pathlib
import re
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
    "ui": dict(family="Sumi UI", file="SumiUI.ttf", size=14, cell=7, asc=12, desc=2, base=13),
}
# the signs, drawn on the face's grid (row 0 = the line's top, as Pillow draws it), in its
# weight. "~" sits on the minus's row.
HAND = {
    "ui": {
        "'": (3, ["...#...", "...#...", "...#..."]),
        '"': (3, ["..#.#..", "..#.#..", "..#.#.."]),
        "`": (3, ["..#....", "...#...", "....#.."]),
        "~": (None, [".##..#.", "#..##.."]),
    },
}
RUN_ON_BLOCKS = [(0x2500, 0x259F), (0x2800, 0x28FF)]   # box lines, blocks, braille: as drawn
# Sumi UI's fill-in (Cozette, 6 × 13): Latin past Latin-1, IPA and the spacing marks, Greek,
# Cyrillic, Latin Extended Additional, and the signs, arrows, shapes and lines of U+2000–U+2BFF
COZETTE_BLOCKS = [(0x00A0, 0x02FF), (0x0370, 0x03FF), (0x0400, 0x04FF), (0x1E00, 0x1EFF), (0x2000, 0x2BFF)]
# Latin Extended-A, composed: Unicode's decomposition gives the face's letter and a mark; the
# marks as the face draws them where it has them (è é ê ë ñ å ç), the rest drawn alike —
# centred over the letter's ink, above a small letter on rows 3–4 (one-row marks: row 4),
# above a capital or a tall letter on rows 1–2 (row 2) — the letter made a row shorter first,
# as the face makes its own É — and below on rows 13–14
MARKS = {
    0x0300: ("above", ["#.", ".#"]),                 # grave (the face's è)
    0x0301: ("above", [".#", "#."]),                 # acute (é)
    0x0302: ("above", [".##.", "#..#"]),             # circumflex (ê)
    0x0303: ("above", [".##..#", "#..##."]),         # tilde (ñ)
    0x0304: ("above", ["####"]),                     # macron
    0x0306: ("above", ["#..#", ".##."]),             # breve
    0x0307: ("above", ["#"]),                        # dot above
    0x0308: ("above", ["#..#"]),                     # diaeresis (ë)
    0x030A: ("above", [".##.", "#..#", ".##."]),     # ring (å)
    0x030B: ("above", [".#..#", "#..#."]),           # double acute
    0x030C: ("above", ["#.#", ".#."]),               # caron
    0x0327: ("below", [".#", "#."]),                 # cedilla (ç)
    0x0328: ("below", ["#.", ".#"]),                 # ogonek (at the letter's right foot)
}
# the face's own capitals made a row shorter for a mark (its Á É Í Ó Ú Ý Ñ): their letter, as is
SHORT = {"A": "Á", "E": "É", "I": "Í", "O": "Ó", "U": "Ú", "Y": "Ý", "N": "Ñ"}
RUN_ON = "_\u2014\u2015\u2017\u203E\u2E3A\u2E3B\u23AF"   # the low line and the long dashes: run on into the next cell


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


def write_font(kind, glyphs, notice, licence, licence_url):
    """The glyphs (codepoint → (advance px, pixels in Pillow rows)) as the face's TrueType file."""
    c = FACES[kind]
    size, cell, asc, desc, base = c["size"], c["cell"], c["asc"], c["desc"], c["base"]
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
        "copyright": notice,
        "licenseDescription": licence,
        "licenseInfoURL": licence_url,
    })
    xh = sorted({y for x, y in glyphs[ord("x")][1]})
    cap = sorted({y for x, y in glyphs[ord("H")][1]})
    fb.setupOS2(sTypoAscender=A, sTypoDescender=D, sTypoLineGap=0, usWinAscent=A,
                usWinDescent=-D, sxHeight=(base - xh[0]) * PX, sCapHeight=(base - cap[0]) * PX,
                achVendID="SUMI", fsType=0, xAvgCharWidth=cell * PX,
                usWeightClass=700, fsSelection=0x20)
    # The face is drawn in one weight (Shinonome's regular, every stroke a pixel) and
    # declared bold: a toolkit asking for bold (a GTK button,
    # <b> in a notification) finds it as it is, and fontconfig's 90-synthetic.conf never smears
    # it a pixel wider — its only face serves regular too.
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


def shorter(pix):
    """A capital or a tall letter a row shorter — its top row 4, for a mark on rows 1–2: the
    row taken out is one that repeats the row above it, nearest the upper third (as the face
    makes its É); with none, the emptiest row of its middle."""
    rows = {}
    for x, y in pix:
        rows.setdefault(y, set()).add(x)
    top, bot = min(rows), max(rows)
    if top >= 4:
        return set(pix)
    aim = top + (bot - top) / 3
    same = [y for y in range(top + 1, bot + 1) if rows.get(y, set()) == rows.get(y - 1, set())]
    cut = min(same, key=lambda y: (abs(y - aim), y)) if same else \
        min(range(top + 2, bot - 1), key=lambda y: (len(rows.get(y, ())), abs(y - aim)))
    return {(x, y + 1 if y < cut else y) for x, y in pix if y != cut}


def mark_on(pix, mark, name):
    """The letter's pixels with the mark (MARKS) on it."""
    where, art = MARKS[mark]
    w = len(art[0])
    xs = [x for x, _ in pix]
    if name in "ıIĳ":                               # (i: centred over its stem, as the face's í)
        stem = max(set(xs), key=xs.count)
        centre = stem
    else:
        centre = (min(xs) + max(xs)) / 2
    x0 = int(centre - (w - 1) / 2 + 0.5)
    if where == "below":
        if mark == 0x0328:                           # (the ogonek: at the right foot)
            x0 = max(xs) - 1
        y0 = 13
        out = set(pix)
    else:
        tall = min(y for _, y in pix) <= 4
        out = shorter(pix) if tall else set(pix)
        y0 = (3 if tall else 5) - len(art)
    out |= {(x0 + i, y0 + j) for j, line in enumerate(art) for i, v in enumerate(line) if v == "#"}
    return out


def build_ui(face_path, cozette_path):
    """Sumi UI: Shinonome Gothic 14 (regular), the signs drawn for it, Latin Extended-A composed
    from its own letters, and Cozette for what else a line holds (the doc string's list)."""
    kind = "ui"
    c = FACES[kind]
    size, cell, asc, desc, base = c["size"], c["cell"], c["asc"], c["desc"], c["base"]
    top = base - asc
    face = ImageFont.truetype(face_path, size)
    coz = ImageFont.truetype(cozette_path, 13)
    fcm = TTFont(face_path, lazy=True).getBestCmap()
    ccm = TTFont(cozette_path, lazy=True).getBestCmap()

    def in_line(pix, adv):
        return all(0 <= x < adv and top <= y < base + desc for x, y in pix)

    glyphs = {}
    # 1. the face: ASCII, the Latin-1 it draws one cell wide, the wide characters, half-width kana
    for cp in fcm:
        ch = chr(cp)
        if not (0x21 <= cp <= 0x7E or 0xA1 <= cp <= 0xFF or (wide(ch) and cp >= 0x2E80)
                or 0xFF61 <= cp <= 0xFF9F):
            continue
        adv = 2 * cell if wide(ch) else cell
        if round(face.getlength(ch)) != adv:
            continue                                 # (° ± × ÷ § ¶ drawn two cells wide: by hand, or Cozette's)
        pix = picture(face, ch, adv + 2, base + desc + 2)
        pix = {(x, y) for x, y in pix if x < adv}
        if not in_line(pix, adv):
            sys.exit(f"build-fonts: Sumi UI: U+{cp:04X} leaves its cell")
        glyphs[cp] = (adv, pix)
    # 2. the five signs, by hand
    minus = sorted({y for x, y in glyphs[ord("-")][1]})
    mid = minus[len(minus) // 2]
    for ch, (row, art) in HAND[kind].items():
        if row is None:
            row = mid - len(art) // 2
        glyphs[ord(ch)] = (cell, {(x, row + i) for i, line in enumerate(art) for x, v in enumerate(line) if v == "#"})
    slash = glyphs[ord("/")][1]
    xs = [x for x, _ in slash]
    glyphs[ord("\\")] = (cell, {(min(xs) + max(xs) - x, y) for x, y in slash})
    # 3. the signs the desktop shows, drawn for this face (art/signs.txt): over the face's own
    # (T among them: Ť Ţ are made from that T)
    for ch, rows in signs(kind, cell).items():
        glyphs[ord(ch)] = (cell, rows)
    # 4. Latin Extended-A from the face's own letters
    dotless = {(x, y) for x, y in glyphs[ord("i")][1] if y > 4}
    glyphs[0x131] = (cell, dotless)                  # ı
    for cp in range(0x100, 0x180):
        if cp in glyphs:
            continue
        d = unicodedata.decomposition(chr(cp)).split()
        if len(d) != 2 or d[0].startswith("<"):
            continue
        b, m = chr(int(d[0], 16)), int(d[1], 16)
        if m not in MARKS or ord(b) not in glyphs:
            continue
        if b in SHORT and MARKS[m][0] == "above" and ord(SHORT[b]) in glyphs:
            letter = {(x, y) for x, y in glyphs[ord(SHORT[b])][1] if y >= 4}   # (the face's own, a row shorter)
        elif b == "i" and MARKS[m][0] == "above":
            letter, b = dotless, "ı"
        else:
            letter = glyphs[ord(b)][1]
        if m == 0x030C and b in "dltL":              # (ď ľ ť Ľ: the caron a small stroke at the right)
            x1 = max(x for x, y in letter if y <= 6) + 1
            glyphs[cp] = (cell, set(letter) | {(min(x1 + (b == "L") * 2, cell - 1), 3), (min(x1 + (b == "L") * 2, cell - 1), 4)})
            continue
        if m == 0x0327 and b == "g":                 # (ģ: the comma turned, above)
            glyphs[cp] = (cell, mark_on(letter, 0x0301, b))
            continue
        glyphs[cp] = (cell, mark_on(letter, m, b))
    glyphs[0x142] = (cell, glyphs[ord("l")][1] | {(2, 8), (4, 6)})          # ł
    glyphs[0x141] = (cell, glyphs[ord("L")][1] | {(1, 7), (2, 6)})          # Ł
    glyphs[0x111] = (cell, glyphs[ord("d")][1] | {(3, 4), (4, 4), (5, 4)})  # đ
    # 5. Cozette: what else a line holds, one cell wide — its baseline (after its row 9) on
    # the face's (after row 12); a third row of descender (its y p g in Greek, Cyrillic) cut
    for a, b in COZETTE_BLOCKS:
        for cp in range(a, b + 1):
            ch = chr(cp)
            if cp not in ccm or wide(ch) or cp in glyphs:
                continue
            cat = unicodedata.category(ch)
            if cat.startswith(("M", "C", "Z")):
                continue
            if round(coz.getlength(ch)) != 6:
                continue
            pix = {(x, y + 3) for x, y in picture(coz, ch, 8, 14) if x < 6 and y + 3 <= base + desc - 1}
            if pix and in_line(pix, cell):
                glyphs[cp] = (cell, pix)
    # 6. a column of air after every letter (the face's own already keep one; a kanji with no
    # gutter loses a column that repeats its neighbour), save what runs on (— ―, the lines)
    for cp in sorted(glyphs):
        adv, pix = glyphs[cp]
        if chr(cp) in RUN_ON or any(a2 <= cp <= b2 for a2, b2 in RUN_ON_BLOCKS) or not pix:
            continue
        if max(x for x, _ in pix) < adv - 1:
            continue
        if min(x for x, _ in pix) > 0:
            glyphs[cp] = (adv, {(x - 1, y) for x, y in pix})
            continue
        colof = lambda x: frozenset(y for x2, y in pix if x2 == x)
        mid_x = (adv - 1) / 2
        spare = [x for x in range(2, adv - 2) if colof(x) == colof(x - 1) or colof(x) == colof(x + 1)]
        if spare:
            x0 = min(spare, key=lambda x: (abs(x - mid_x), x))
            glyphs[cp] = (adv, {(x if x < x0 else x - 1, y) for x, y in pix if x != x0})
        elif adv == cell:                            # (no column repeats: two neighbours made one —
            x0 = min(range(1, adv - 2),               #  the pair that differ least, nearest the middle)
                     key=lambda x: (len(colof(x) ^ colof(x + 1)), abs(x + 0.5 - mid_x), x))
            glyphs[cp] = (adv, {(x if x <= x0 else x - 1, y) for x, y in pix})
    glyphs[0x20] = (cell, set())
    glyphs[0xA0] = (cell, set())
    glyphs[0x3000] = (2 * cell, set())
    write_air(glyphs, cell)
    coz_notice = TTFont(cozette_path, lazy=True)["name"].getDebugName(13) or ""
    return write_font(kind, glyphs,
                      "Shinonome Gothic 14 (public domain, via JF Dot fonts 2015-05-27) and Cozette "
                      "1.30.0 (MIT License, Copyright (c) 2020, Ines <ines@moonwit.ch>).",
                      "This font: the MIT License, as Cozette's (the Shinonome parts are in the public "
                      "domain).\n\n" + coz_notice, "https://github.com/the-moonwitch/Cozette/blob/master/LICENSE")


def write_air(glyphs, cell):
    """width.sh's air tables (the bar's l/r classes): each printable ASCII letter's empty
    columns before its ink and after it, 0–3 px."""
    L = "".join(str(min(min(x for x, _ in glyphs[cp][1]), 3)) for cp in range(33, 127))
    R = "".join(str(min(cell - 1 - max(x for x, _ in glyphs[cp][1]), 3)) for cp in range(33, 127))
    f = ROOT / "configs/home/.config/fedokawaii/width.sh"
    t = f.read_text()
    t2 = re.sub(r"^__AIR_L=\d+$", "__AIR_L=" + L, t, flags=re.M)
    t2 = re.sub(r"^__AIR_R=\d+$", "__AIR_R=" + R, t2, flags=re.M)
    if t2.count("__AIR_L=" + L) != 1 or t2.count("__AIR_R=" + R) != 1:
        sys.exit("build-fonts: width.sh has no __AIR_L/__AIR_R line to write")
    f.write_text(t2)


def main(argv):
    if len(argv) != 3 or argv[0] != "ui":
        sys.exit(__doc__.split("\n\n")[1])
    n = build_ui(argv[1], argv[2])
    print(f"Sumi UI: {n} characters → {OUT / FACES['ui']['file']}")


if __name__ == "__main__":
    main(sys.argv[1:])
