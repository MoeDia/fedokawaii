#!/usr/bin/env python3
"""tools/build-seal.py — the launcher's heading as a colour font, one per theme.

    python3 tools/build-seal.py

fuzzel draws its prompt as one run of text in one colour, so it cannot draw a heading
(docs/design-system.md §4: a seal — the kanji in accent_text in a 1 px edge2 frame —, 6 px,
the name in text, 6 px, the stitch in edge2) in its three inks. A glyph of a colour font
keeps the colours it was drawn in (COLR/CPAL: FreeType renders it for fcft), whatever the
colour of the run around it; so the heading is two such glyphs, in the theme's own inks,
and each theme's fuzzel.ini names its own font:

    configs/home/.local/share/fonts/SumiSealInk.ttf     "Sumi Seal Ink"    (dark)
    configs/home/.local/share/fonts/SumiSealPaper.ttf   "Sumi Seal Paper"  (light)

On Fusion Pixel 12's grid (100 units a pixel, the baseline at 0), its letters copied from
it (Fusion Pixel: SIL Open Font License 1.1, so this font is under it too):
    U+FE800  the prompt: the seal, 23 × 23 — the frame, and 起 inside it with 5 px of air all
             round; its advance 23, so what you type starts where the name stands
    U+FE801  the name "launcher", and the 6 px after it
    U+FE802  the stitch — 3 px on, 2 off, 1 px high through the seal's middle row — 65 px of
             it; U+FE803 the rest of it, to x 284 of the window. The placeholder is U+FE801,
             U+FE802 twice, U+FE803: FreeType draws a colour glyph that wide and that thin
             only in pieces (one stitch of 187 px fails in its rasteriser, 2.14: Raster_Overflow)
Both sit one pixel lower than Fusion's own letters on the prompt's line would: fuzzel puts
that line's baseline at 28 (frame 2, vertical-pad 12, then the row's 14), which would put
the seal's frame at y 13; drawn from 29 it stands at 14, 12 px inside the window's frame,
and the list's first row (43) comes 6 px under it, as in a panel.
Across: the prompt starts at x 20 (frame 2 + horizontal-pad 18), the seal's frame at 14 —
the content's edge — the name at 43. The stitch ends at 284, not at the content's edge (290):
fuzzel draws no glyph whose ink passes its text margin (304 - 2 - 18).
Outputs are committed (a normal install needs neither Python nor the Fusion font file);
run again after changing a colour in tools/build-themes.py.
"""
import importlib.util
import pathlib
import subprocess

from fontTools.colorLib.builder import buildCOLR, buildCPAL
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables import ttProgram

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONTS = ROOT / "configs/home/.local/share/fonts"
PX, UPM, ASC, DESC = 100, 1200, 1000, -200   # Fusion Pixel 12's em and line
SEAL, NAME, STITCH_A, STITCH_B = 0xFE800, 0xFE801, 0xFE802, 0xFE803
KANJI, WORD = "起", "launcher"
DROP = 1                                     # pixels below Fusion's own baseline (see above)
LEFT, RIGHT = 20, 284                        # the window's x where the prompt starts · the text margin
FILES = {"dark": ("SumiSealInk.ttf", "Sumi Seal Ink"), "light": ("SumiSealPaper.ttf", "Sumi Seal Paper")}
INKS = ("edge2", "accent_text", "text")      # CPAL entries 0, 1, 2


def palette():
    spec = importlib.util.spec_from_file_location("themes", ROOT / "tools/build-themes.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.P


def fusion():
    path = subprocess.run(["fc-match", "-f", "%{file}", "Fusion Pixel 12px Mono ja"],
                          capture_output=True, text=True, check=True).stdout
    f = TTFont(path)
    if f["head"].unitsPerEm != UPM:
        raise SystemExit(f"{path}: not Fusion Pixel 12 ({f['head'].unitsPerEm} units an em)")
    return f


def rects(pen, boxes):
    for x0, y0, x1, y1 in boxes:              # pixels: x0..x1 across, y0..y1 up from the baseline
        L, R, B, T = x0 * PX, x1 * PX, (y0 - DROP) * PX, (y1 - DROP) * PX
        pen.moveTo((L, B)); pen.lineTo((L, T)); pen.lineTo((R, T)); pen.lineTo((R, B))
        pen.closePath()                       # clockwise: TrueType's filled direction


def letters(pen, src, text, x_px):
    cmap, gs = src.getBestCmap(), src.getGlyphSet()
    for ch in text:
        g = cmap[ord(ch)]
        gs[g].draw(TransformPen(pen, (1, 0, 0, 1, x_px * PX, -DROP * PX)))
        x_px += src["hmtx"][g][0] // PX


# the seal, from the prompt's pen (the kanji's: its ink x 0–10, y -2–8): the frame x -6–16,
# y -8–14, 1 px; its middle row y 3
FRAME = [(-6, 14, 17, 15), (-6, -8, 17, -7), (-6, -7, -5, 14), (16, -7, 17, 14)]
SEAL_ADV = 23
MID = 3
NAME_ADV = 6 * len(WORD) + 6                  # Fusion's Latin, 6 px each; then the air
STITCH_W = RIGHT - (LEFT + SEAL_ADV + NAME_ADV)   # 187
PIECE = 65                                    # a whole number of 5 px steps: the pieces join
REST = STITCH_W - 2 * PIECE                   # 57: the last one, its last whole stitch 4 px short of the end


def stitch(w):
    """whole stitches only, from the left: the last one that fits ends up to 4 px short of w"""
    return [(x, MID, x + 3, MID + 1) for x in range(0, w - 2, 5)]


def build(src, path, family, inks):
    layers = {"seal.frame": lambda p: rects(p, FRAME), "seal.kanji": lambda p: letters(p, src, KANJI, 0),
              "name.word": lambda p: letters(p, src, WORD, 0),
              "stitch.piece": lambda p: rects(p, stitch(PIECE)), "rest.piece": lambda p: rects(p, stitch(REST))}
    bases = ("seal", "name", "stitch", "rest")
    order = [".notdef", "space", *bases, *layers]
    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({0x20: "space", SEAL: "seal", NAME: "name", STITCH_A: "stitch", STITCH_B: "rest"})
    glyphs = {".notdef": TTGlyphPen(None).glyph(), "space": TTGlyphPen(None).glyph()}
    for n, draw in layers.items():
        pen = TTGlyphPen(None)
        draw(pen)
        glyphs[n] = pen.glyph()
    for base in bases:                        # the plain fallback: every layer in one
        pen = TTGlyphPen(None)
        for n, draw in layers.items():
            if n.startswith(base + "."):
                draw(pen)
        glyphs[base] = pen.glyph()
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    adv = {"seal": SEAL_ADV, "name": NAME_ADV, "stitch": PIECE, "rest": REST}
    metrics = {}
    for n in order:                            # lsb = the ink's real left edge (FreeType's rule)
        g = glyf[n]
        g.recalcBounds(glyf)
        metrics[n] = (adv.get(n.split(".")[0], 6) * PX, g.xMin if g.numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASC, descent=DESC, lineGap=0)
    fb.setupNameTable({
        "familyName": family, "styleName": "Regular", "uniqueFontIdentifier": family + " Regular",
        "fullName": family, "psName": family.replace(" ", "") + "-Regular", "version": "Version 1.0",
        "copyright": "The launcher's heading, drawn for this desktop; its letters are Fusion Pixel's, "
                     "Copyright (c) 2022, TakWolf (https://takwolf.com)",
        "licenseDescription": "This Font Software is licensed under the SIL Open Font License, Version 1.1",
        "licenseInfoURL": "https://openfontlicense.org",
    })
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=DESC, sTypoLineGap=0, usWinAscent=ASC,
                usWinDescent=-DESC, achVendID="SUMI", fsType=0)
    fb.setupPost(isFixedPitch=0)
    fb.setupHead(unitsPerEm=UPM, fontRevision=1.0, created=0x7C259DC0, modified=0x7C259DC0)
    fb.font["CPAL"] = buildCPAL([[tuple(int(c[i:i + 2], 16) / 255 for i in (0, 2, 4)) + (1.0,) for c in inks]])
    fb.font["COLR"] = buildCOLR({
        "seal": [("seal.frame", 0), ("seal.kanji", 1)],
        "name": [("name.word", 2)],
        "stitch": [("stitch.piece", 0)],
        "rest": [("rest.piece", 0)],
    })
    fpgm = newTable("fpgm")                    # hinted by itself: no autohinter moving pixels
    fpgm.program = ttProgram.Program()
    fpgm.program.fromAssembly(["SVTCA[0]"])
    fb.font["fpgm"] = fpgm
    FONTS.mkdir(parents=True, exist_ok=True)
    fb.save(str(path))


if __name__ == "__main__":
    P, src = palette(), fusion()
    for mode, (file, family) in FILES.items():
        build(src, FONTS / file, family, [P[mode][k] for k in INKS])
        print(f"{file}: {family}, " + ", ".join(f"{k} #{P[mode][k]}" for k in INKS))
