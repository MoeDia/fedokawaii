#!/usr/bin/env python3
"""tools/build-icons.py — build the desktop's pixel icon font from art/icons.txt.

    python3 tools/build-icons.py            # writes the font and icons.sh
    python3 tools/build-icons.py --preview out.png   # also draws every icon, 8x, centred

Outputs (all committed, so a normal install needs neither Python nor fontTools):
    configs/home/.local/share/fonts/SumiIcons.ttf       "Sumi Icons": bar, menus, notices
    configs/home/.local/share/fonts/SumiIconsTerm.ttf   "Sumi Icons Term": the same drawings
        on the terminal's font, Fusion Pixel 10 (a 10 px em: at its 20 px every drawing
        pixel is 2 × 2, a 10 × 10 icon exactly two of its 5-px cells wide and its line
        high), without their 2 px of air on the left (foot draws each from the left edge of
        its cell, so the air would only push the icon into the space after it: prompt,
        fetch, the pop-ups' titles)
    configs/home/.config/fedokawaii/icons.sh

The font copies Fusion Pixel 12's grid: 1200 units per em, 100 units per pixel, so at
12 px (or 24, 36…) every pixel of the drawing lands on exactly one screen pixel.
Each run of '#' is merged into rectangles, so the outlines are few and gap-free.
Needs: python3-fonttools (dnf install python3-fonttools).
"""
import argparse
import pathlib
import re
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables import ttProgram

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "icons.txt"
TTF = ROOT / "configs/home/.local/share/fonts/SumiIcons.ttf"
TERM_TTF = ROOT / "configs/home/.local/share/fonts/SumiIconsTerm.ttf"
TERM_RAISE = 0                    # pixels: the terminal's font is Fusion Pixel too, same middle
TERM_SHIFT = 2                    # pixels to the left: an icon's ink starts at its cell's edge
TERM_UPM, TERM_ASC, TERM_DESC = 1000, 900, -100   # Fusion Pixel 10's em and line: 9 up, 1 down
                                  # (a 10-row icon fills it; the capitals' middle stays 4 up)
SH = ROOT / "configs/home/.config/fedokawaii/icons.sh"

UPM, PX = 1200, 100               # Fusion Pixel 12: 12 px em, 100 units per pixel
ASC, DESC = 1000, -200            # same line metrics, so mixing the fonts keeps the line
FIRST = 0xFE000                   # Supplementary Private Use Area A
MIDDLE = 4                        # text middle in pixels above the baseline


def parse(text):
    icons, cur = [], None
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if cur is None and (line == "#" or line.startswith("# ")):
            continue                         # a comment between icons
        if line.startswith("@"):
            name, *opts = line[1:].split()
            if not re.fullmatch(r"[a-z][a-z0-9-]*", name):
                sys.exit(f"icons.txt:{n}: bad icon name {name!r}")
            settings = {}
            for o in opts:
                k, _, v = o.partition("=")
                if k not in ("adv", "x") or not re.fullmatch(r"-?\d+", v):
                    sys.exit(f"icons.txt:{n}: bad setting {o!r}")
                settings[k] = int(v)
            cur = {"name": name, "rows": [], "line": n, **settings}
            icons.append(cur)
        elif re.fullmatch(r"[#.]+", line):
            if cur is None:
                sys.exit(f"icons.txt:{n}: drawing outside an icon")
            cur["rows"].append(line)
        elif not line:
            cur = None
    seen = set()
    for ic in icons:
        rows, name = ic["rows"], ic["name"]
        if name in seen:
            sys.exit(f"icons.txt:{ic['line']}: {name} drawn twice")
        seen.add(name)
        if not rows:
            sys.exit(f"icons.txt:{ic['line']}: {name} has no drawing")
        widths = {len(r) for r in rows}
        if len(widths) != 1:
            sys.exit(f"icons.txt:{ic['line']}: {name} rows differ in width {sorted(widths)}")
        w, h = widths.pop(), len(rows)
        # two kinds: even × even, centred on the Latin capitals (beside words); and seal-sized,
        # 11 rows, odd × odd, centred exactly like Fusion Pixel's kanji (ink rows 1–11 of
        # the line, columns 0–10) — the bar's buttons, which hold kanji and icons alike
        if h % 2 and h != 11:
            sys.exit(f"icons.txt:{ic['line']}: {name} is {h} rows; heights are even, or 11 (seal-sized)")
        if "x" not in ic and (w % 2) != (h % 2):
            sys.exit(f"icons.txt:{ic['line']}: {name} is {w} × {h}; even × even, or odd × 11")
        ic["w"], ic["h"] = w, h
        ic.setdefault("adv", w + 4)
        ic.setdefault("x", (ic["adv"] - w) // 2)
    return icons


def rectangles(rows):
    """Greedy merge: horizontal runs, extended down while the run repeats exactly."""
    h, w = len(rows), len(rows[0])
    used = [[False] * w for _ in range(h)]
    out = []
    for y in range(h):
        x = 0
        while x < w:
            if rows[y][x] != "#" or used[y][x]:
                x += 1
                continue
            x1 = x
            while x1 < w and rows[y][x1] == "#" and not used[y][x1]:
                x1 += 1
            y1 = y + 1
            while y1 < h and all(rows[y1][i] == "#" and not used[y1][i] for i in range(x, x1)):
                y1 += 1
            for yy in range(y, y1):
                for i in range(x, x1):
                    used[yy][i] = True
            out.append((x, y, x1, y1))       # columns x..x1, rows y..y1 (top-down)
            x = x1
    return out


def glyph(ic, raise_px=0, shift=0):
    pen = TTGlyphPen(None)
    top = MIDDLE + raise_px + ic["h"] // 2   # pixel row 0 sits just below this line
    x = ic["x"] - min(shift, max(ic["x"], 0))  # (never left of the pen)
    for x0, y0, x1, y1 in rectangles(ic["rows"]):
        L, R = (x + x0) * PX, (x + x1) * PX
        T, B = (top - y0) * PX, (top - y1) * PX
        pen.moveTo((L, B)); pen.lineTo((L, T)); pen.lineTo((R, T)); pen.lineTo((R, B))
        pen.closePath()                      # clockwise: TrueType's filled direction
    return pen.glyph()


def build(icons, path=TTF, family="Sumi Icons", raise_px=0, shift=0, upm=UPM, asc=ASC, desc=DESC):
    names = [".notdef", "space"] + ["i_" + ic["name"].replace("-", "_") for ic in icons]
    fb = FontBuilder(upm, isTTF=True)
    fb.setupGlyphOrder(names)
    fb.setupCharacterMap({0x20: "space", **{FIRST + i: names[i + 2] for i in range(len(icons))}})
    notdef = TTGlyphPen(None)                # a hollow box: outer clockwise, inner hole anticlockwise
    notdef.moveTo((100, 0)); notdef.lineTo((100, 800)); notdef.lineTo((600, 800)); notdef.lineTo((600, 0))
    notdef.closePath()
    notdef.moveTo((200, 100)); notdef.lineTo((500, 100)); notdef.lineTo((500, 700)); notdef.lineTo((200, 700))
    notdef.closePath()
    glyphs = {".notdef": notdef.glyph(), "space": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (700, 100), "space": (600, 0)}
    for ic, name in zip(icons, names[2:]):
        glyphs[name] = glyph(ic, raise_px, shift)
        metrics[name] = (ic["adv"] * PX, ic["x"] * PX)
    fb.setupGlyf(glyphs)
    glyf = fb.font["glyf"]
    for name in names:                       # lsb must equal the ink's real left edge (xMin),
        g = glyf[name]                       # or FreeType shifts the drawing by the difference
        g.recalcBounds(glyf)
        metrics[name] = (metrics[name][0], g.xMin if g.numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=asc, descent=desc, lineGap=0)
    ps = family.replace(" ", "")
    fb.setupNameTable({
        "familyName": family, "styleName": "Regular",
        "uniqueFontIdentifier": family + " Regular", "fullName": family,
        "psName": ps + "-Regular", "version": "Version 1.0",
        "copyright": "Drawn for this desktop; free to use and change.",
    })
    fb.setupOS2(sTypoAscender=asc, sTypoDescender=desc, sTypoLineGap=0,
                usWinAscent=asc, usWinDescent=-desc, sxHeight=(asc - 400) // PX * PX, sCapHeight=(asc - 200) // PX * PX,
                achVendID="SUMI", fsType=0)
    fb.setupPost(isFixedPitch=0)
    fb.setupHead(unitsPerEm=upm, fontRevision=1.0)
    for g in glyphs.values():                # bounding boxes for head/hhea/glyf
        g.recalcBounds(fb.font["glyf"])
    # A font without instructions is auto-hinted by FreeType (GTK asks for "slight"
    # hinting), which moves edges by a pixel: icons came out 11 px wide instead of 10, or
    # a row too tall. One harmless instruction in fpgm marks the font as hinted by itself,
    # and every pixel lands where it is drawn, at 11 and 22 px, smoothed or not.
    fpgm = newTable("fpgm")
    fpgm.program = ttProgram.Program()
    fpgm.program.fromAssembly(["SVTCA[0]"])
    fb.font["fpgm"] = fpgm
    path.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(path))


def write_sh(icons):
    out = [
        "# ~/.config/fedokawaii/icons.sh — the desktop's pixel icons (font \"Sumi Icons\").",
        "# Generated by tools/build-icons.py from art/icons.txt: edit the drawing, not this file.",
        "# Written as UTF-8 bytes so the meaning never depends on the locale. Source it:",
        "#   . ~/.config/fedokawaii/icons.sh; printf '%s volume\\n' \"$ICON_SPEAKER\"",
        "# shellcheck shell=bash disable=SC2034",
    ]
    for i, ic in enumerate(icons):
        b = chr(FIRST + i).encode()
        esc = "".join(f"\\x{c:02x}" for c in b)
        var = "ICON_" + ic["name"].upper().replace("-", "_")
        out.append(f"{var}=$'{esc}'")
    # ICON_BAR_<NAME>: the icon as the bar draws it before a value, no space between:
    # exactly 6 px from its ink to the value's (its own air on the right made up with 2 px
    # and 1 px spaces, or — more air than 6 — its tight twin, the same drawing without it);
    # and a family's (vol-0 … vol-4, bri-0 … bri-4) ink starting at one place, the
    # leftmost of them (1 px and 2 px spaces in front), so a module's edge never moves
    code = {ic["name"]: chr(FIRST + i).encode() for i, ic in enumerate(icons)}
    def esc(b): return "".join(f"\\x{c:02x}" for c in b)
    def spaces(n): return code["gap"] * (n // 2) + code["gap1"] * (n % 2)
    lead = {}
    for ic in icons:
        if not ic.get("twin") and not ic["name"].startswith("gap"):
            lead.setdefault(family(ic["name"]), []).append(left_air(ic))
    out.append("# on the bar: \"$ICON_BAR_X$value\" (6 px from the icon's ink to the value's)")
    for ic in icons:
        if ic.get("twin") or ic["name"].startswith("gap"):
            continue
        name, air = ic["name"], right_air(ic)
        sp = code[name + "-tight"] + spaces(6) if air > 6 else code[name] + spaces(6 - air)
        sp = spaces(max(lead[family(name)]) - left_air(ic)) + sp
        out.append(f"ICON_BAR_{name.upper().replace('-', '_')}=$'{esc(sp)}'")
    SH.parent.mkdir(parents=True, exist_ok=True)
    SH.write_text("\n".join(out) + "\n")


def preview(icons, path, scale=8):
    """A sheet of every drawing: each one centred to the pixel in a tile of its own (by its
    ink, so a narrow one sits in the middle like a wide one), its name centred under it."""
    from PIL import Image, ImageDraw, ImageFont
    label = None
    for f in ("/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if pathlib.Path(f).exists():
            label = ImageFont.truetype(f, 18)
            break
    label = label or ImageFont.load_default()
    cols, tile, gap, text = 8, 18 * scale, 6, 36       # tile: 18 drawing pixels square
    rows = (len(icons) + cols - 1) // cols
    W = cols * tile + (cols + 1) * gap
    H = rows * (tile + text) + (rows + 1) * gap
    img = Image.new("RGB", (W, H), (15, 14, 12))
    d = ImageDraw.Draw(img)
    for i, ic in enumerate(icons):
        r, c = divmod(i, cols)
        short = cols - min(cols, len(icons) - r * cols)        # a last, shorter row: centred
        x0 = gap + c * (tile + gap) + short * (tile + gap) // 2
        y0 = gap + r * (tile + text + gap)
        d.rectangle((x0, y0, x0 + tile - 1, y0 + tile - 1), fill=(22, 20, 17))
        ink = [(x, y) for y, r in enumerate(ic["rows"]) for x, c in enumerate(r) if c == "#"]
        if ink:
            l, t = min(x for x, _ in ink), min(y for _, y in ink)
            w = max(x for x, _ in ink) - l + 1
            h = max(y for _, y in ink) - t + 1
            ox, oy = x0 + (tile - w * scale) // 2, y0 + (tile - h * scale) // 2   # (scale even: exact)
            for x, y in ink:
                X, Y = ox + (x - l) * scale, oy + (y - t) * scale
                d.rectangle((X, Y, X + scale - 1, Y + scale - 1), fill=(207, 195, 166))
        tw = d.textlength(ic["name"], font=label)
        d.text((x0 + (tile - tw) / 2, y0 + tile + 8), ic["name"], fill=(135, 127, 111), font=label)
    img.save(path)


def left_air(ic):
    return ic["x"] + min(r.index("#") for r in ic["rows"] if "#" in r)


def right_air(ic):
    return ic["adv"] - ic["x"] - max(r.rindex("#") for r in ic["rows"] if "#" in r) - 1


def family(name):
    """vol-3 and vol-mute → vol: the icons of one module that stand for one another"""
    return re.sub(r"-(\d+|mute)$", "", name)


def twins(icons):
    """the tight twins (ICON_BAR_*): an icon with more than 6 px of air on its right, again
    without it — after every other, so no icon's code ever changes"""
    return icons + [{**ic, "name": ic["name"] + "-tight", "adv": ic["adv"] - right_air(ic), "twin": True}
                    for ic in icons if not ic["name"].startswith("gap") and right_air(ic) > 6]


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", metavar="PNG")
    a = ap.parse_args()
    icons = twins(parse(SRC.read_text()))
    build(icons)
    build(icons, TERM_TTF, "Sumi Icons Term", TERM_RAISE, TERM_SHIFT, TERM_UPM, TERM_ASC, TERM_DESC)
    write_sh(icons)
    print(f"{len(icons)} icons → {TTF.relative_to(ROOT)}, {TERM_TTF.relative_to(ROOT)}, {SH.relative_to(ROOT)}")
    if a.preview:
        preview(icons, a.preview)


if __name__ == "__main__":
    main()
