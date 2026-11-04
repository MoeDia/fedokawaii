#!/usr/bin/env python3
"""tools/build-iso-art.py — the installer ISO's pictures, every one from the desktop's own sources.

    python3 tools/build-iso-art.py OUTDIR

Writes (tools/build-iso.sh calls it, with SOURCE_DATE_EPOCH set; nothing here reads the clock):
    OUTDIR/console/sumi-console.psf   Sumi UI ×2 (design system §2: the installer's screens) as a
        Linux console font, a 14 × 28 cell, with our icons, the torii and the screens' own tiles in
        the Private Use Area
    OUTDIR/console/glyphs.py          the names of those tiles, the palette's roles, for iso/screens/
    OUTDIR/grub/…                     the boot menu's theme: PNG only, words too (under Secure Boot
        Fedora's GRUB refuses any font but the Unifont inside its signed image: iso-research.md §5)
    OUTDIR/plymouth/…                 the boot splash of the first stage: system/plymouth/sumi with
        our name in place of "starting Fedora"
    OUTDIR/ground                     the ground's colour, for iso/grub.cfg
Needs: Pillow. Colours from tools/build-themes.py's dark palette: the boot is always ink.
"""
import importlib.util
import pathlib
import re
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True
ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("themes", ROOT / "tools/build-themes.py")
themes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themes)
P = themes.P["dark"]
FONT = ROOT / "system/fonts/SumiUI.ttf"
CELL_W, CELL_H = 14, 28           # Sumi UI's fixed 7 px letter on its 14 px em, twice
UI = ImageFont.truetype(str(FONT), 14)

# the icons the screens use (art/icons.txt); each two cells wide, one tall
ICONS = ("torii-small", "user", "lock", "drive", "globe", "keyboard", "monitor", "check", "cross", "download",
         "power", "restart", "ethernet", "chevron", "hg-0", "hg-1", "hg-2", "hg-3", "hg-4")
# what the letters' font itself must carry beyond ASCII
SIGNS = "·◆×"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def letter(ch):
    """A character of Sumi UI at its own 14 px: 7 × 14, every pixel on or off."""
    im = Image.new("1", (7, 14), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((0, 0), ch, font=UI, fill=1)
    return im


def double(im):
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def icon(name, cells=2):
    """art/icons.txt's drawing, doubled, centred on its cells."""
    rows, on = [], False
    for line in (ROOT / "art/icons.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("@"):
            if on:
                break
            on = line.split()[0] == "@" + name
        elif on and line and set(line) <= set("#."):
            rows.append(line)
    if not rows:
        sys.exit(f"build-iso-art: no icon {name} in art/icons.txt")
    w, h = max(map(len, rows)), len(rows)
    im = Image.new("1", (CELL_W * cells, CELL_H), 0)
    x0, y0 = (CELL_W * cells - w * 2) // 2, (CELL_H - h * 2) // 2
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                for dy in (0, 1):
                    for dx in (0, 1):
                        im.putpixel((x0 + 2 * x + dx, y0 + 2 * y + dy), 1)
    return im


def xpm_rows(path):
    rows = re.findall(r'"([^"]*)"', path.read_text())
    w, h, ncol, _ = map(int, rows[0].split())
    colours = {}
    for line in rows[1:1 + ncol]:
        colours[line[0]] = line.split()[-1]
    return w, h, colours, rows[1 + ncol:1 + ncol + h]


def xpm(path):
    w, h, colours, rows = xpm_rows(path)
    im = Image.new("RGBA", (w, h))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            v = colours[c]
            im.putpixel((x, y), (0, 0, 0, 0) if v == "None" else rgb(v.lstrip("#")) + (255,))
    return im


def tiles(bitmap, cols, rows):
    """A 1-bit picture cut into cells, left to right, top to bottom."""
    return [bitmap.crop((c * CELL_W, r * CELL_H, (c + 1) * CELL_W, (r + 1) * CELL_H))
            for r in range(rows) for c in range(cols)]


def psf(glyphs):
    """A PSF2 font with a Unicode table. glyphs: [(picture, [code points])]; at most 256, so the
    console keeps 16 colours for both ink and ground (fbcon gives a 512-glyph font 8 grounds)."""
    if len(glyphs) > 256:
        sys.exit(f"build-iso-art: {len(glyphs)} glyphs, the console's limit for 16 grounds is 256")
    # (every ASCII letter on its own number: the console erases with glyph 0x20, unmapped, so that
    # one must be the blank — anything else there shows faintly over the whole screen)
    blank = (Image.new("1", (CELL_W, CELL_H), 0), [])
    ascii_ = {g[1][0]: g for g in glyphs if 0x20 <= g[1][0] < 0x7F}
    rest = [g for g in glyphs if not 0x20 <= g[1][0] < 0x7F]
    glyphs = rest[:0x20] + [blank] * (0x20 - len(rest[:0x20])) + [ascii_[c] for c in range(0x20, 0x7F)]
    glyphs += rest[0x20:] + [blank] * (256 - len(glyphs) - len(rest[0x20:]))
    bytes_row = (CELL_W + 7) // 8
    head = struct.pack("<4B7I", 0x72, 0xb5, 0x4a, 0x86, 0, 32, 1, len(glyphs),
                       bytes_row * CELL_H, CELL_H, CELL_W)
    data = bytearray(head)
    for im, _ in glyphs:
        px = im.load()
        for y in range(CELL_H):
            v = 0
            for x in range(CELL_W):
                v = (v << 1) | (1 if px[x, y] else 0)
            v <<= bytes_row * 8 - CELL_W
            data += v.to_bytes(bytes_row, "big")
    for _, cps in glyphs:
        for cp in cps:
            data += chr(cp).encode("utf-8")
        data.append(0xFF)
    return bytes(data)


def console(out):
    out.mkdir(parents=True, exist_ok=True)
    glyphs = [(double(letter(" ")), [0x20, 0xA0])]
    for cp in range(0x21, 0x7F):
        glyphs.append((double(letter(chr(cp))), [cp]))
    glyphs[ord("?") - 0x20][1].append(0xFFFD)      # (what the console draws for what it has not)
    for ch in SIGNS:
        glyphs.append((double(letter(ch)), [ord(ch)]))
    # the rule: 2 px, on the x-height's middle, flush cell to cell (Sumi UI's own ─ stops a pixel short)
    rule = Image.new("1", (CELL_W, CELL_H), 0)
    ImageDraw.Draw(rule).rectangle([0, 14, CELL_W - 1, 15], fill=1)
    glyphs.append((rule, [0x2500]))
    names = {}
    next_cp = 0xE000

    def add(name, parts):
        nonlocal next_cp
        names[name] = "".join(chr(next_cp + i) for i in range(len(parts)))
        for i, g in enumerate(parts):
            glyphs.append((g, [next_cp + i]))
        next_cp += len(parts)

    for name in ICONS:
        add(name, tiles(icon(name), 2, 1))
    # the torii as the splash shows it: art/grub/torii.xpm ×8, 88 × 88, in 7 cells × 4 rows
    w, h, colours, rows = xpm_rows(ROOT / "art/grub/torii.xpm")
    big = Image.new("1", (7 * CELL_W, 4 * CELL_H), 0)
    x0, y0 = (big.width - w * 8) // 2, (big.height - h * 8) // 2
    d = ImageDraw.Draw(big)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if colours[c] != "None":
                d.rectangle([x0 + x * 8, y0 + y * 8, x0 + x * 8 + 7, y0 + y * 8 + 7], fill=1)
    add("torii_big", tiles(big, 7, 4))
    # the meter (design system §7): segments, a cell each — solid, and hollow for what is to come
    add("seg_on", [icon("read", 1)])
    add("seg_off", [icon("read-off", 1)])
    # a dot of the splash's three, 6 × 6 doubled to the cell's middle
    dot = Image.new("1", (CELL_W, CELL_H), 0)
    ImageDraw.Draw(dot).rectangle([4, 11, 9, 16], fill=1)
    add("dot", [dot])
    (out / "sumi-console.psf").write_bytes(psf(glyphs))
    lines = ['"""the console font\'s tiles and the palette\'s roles (written by tools/build-iso-art.py)."""', "G = {"]
    lines += [f"    {k!r}: {v!r}," for k, v in sorted(names.items())]
    lines += ["}", "COLOURS = {"]
    roles = ("ground", "select", "surface", "accent", "edge2", "edge", "edge", "text",       # (0–7: inks and grounds)
             "faint", "muted", "text", "strong", "accent_text", "asagi", "gold", "text_on_select")
    lines += [f"    {i}: {P[r]!r},  # {r}" for i, r in enumerate(roles)]
    lines += ["}", ""]
    (out / "glyphs.py").write_text("\n".join(lines), encoding="utf-8")
    return len(glyphs)


MENU = (("fkinstall", "install fedokawaii"),
        ("fkcheck", "check this stick, then install"),
        ("fkoff", "turn the PC off"))        # (three lines: GRUB's list is never shorter than three rows)


def words(text, colour):
    """Words in Sumi UI ×2 on nothing, as wide as GRUB's icon column (MENU_W)."""
    im = Image.new("RGBA", (MENU_W, 28), (0, 0, 0, 0))
    small = Image.new("1", (7 * len(text), 14), 0)
    d = ImageDraw.Draw(small)
    d.fontmode = "1"
    d.text((0, 0), text, font=UI, fill=1)
    px = small.load()
    c = rgb(colour) + (255,)
    for y in range(small.height):
        for x in range(small.width):
            if px[x, y]:
                for dy in (0, 1):
                    for dx in (0, 1):
                        im.putpixel((2 * x + dx, 2 * y + dy), c)
    return im


MENU_W = 14 * 34                 # the longest entry's letters and a little air, whole letters


def solid(path, w, h, colour):
    Image.new("RGB", (w, h), rgb(colour)).save(path, optimize=True)


def hem(path):
    """The menu's hem, as theme.sh makes it for the installed system: rows of the wave tile in a
    quiet line colour, fading upwards in an ordered dither, ×2, wide enough for a 4K screen."""
    tw, th, _, tile = xpm_rows(ROOT / "art/grub/pattern.xpm")
    w, h = 1920, 24 * 5
    bayer = [[0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
             [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
             [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
             [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    line = rgb(P["edge2"]) + (255,)
    for y in range(h):
        level = (y + 0.5) / h * 64
        for x in range(w):
            if tile[y % th][x % tw] == "." and bayer[y % 8][x % 8] < level:
                im.putpixel((x, y), line)
    im.resize((w * 2, h * 2), Image.NEAREST).save(path, optimize=True)


def grub(out):
    (out / "icons").mkdir(parents=True, exist_ok=True)
    gs = 2
    for cls, text in MENU:
        words(text, P["strong"]).save(out / "icons" / f"{cls}.png", optimize=True)
    torii = xpm(ROOT / "art/grub/torii.xpm")
    torii.resize((torii.width * 8, torii.height * 8), Image.NEAREST).save(out / "torii.png", optimize=True)
    hem(out / "hem.png")
    solid(out / "menu_c.png", 1, 1, P["surface"])
    for part in ("n", "s", "e", "w", "nw", "ne", "sw", "se"):
        solid(out / f"menu_{part}.png", 1, 1, P["edge"])
    solid(out / "select_c.png", 1, 1, P["select"])
    for part in ("w", "e"):
        solid(out / f"select_{part}.png", 4 * gs, 1, P["select"])
    ph = 14 * gs
    bar = Image.new("RGBA", (1, ph), (0, 0, 0, 0))
    bar.putpixel((0, 0), rgb(P["edge"]) + (255,))
    bar.putpixel((0, gs + 1), rgb(P["edge"]) + (255,))
    for y in range(1, gs + 1):
        bar.putpixel((0, y), rgb(P["surface"]) + (255,))
    bar.save(out / "bar_c.png", optimize=True)
    end = Image.new("RGBA", (1, ph), (0, 0, 0, 0))
    for y in range(0, gs + 2):
        end.putpixel((0, y), rgb(P["edge"]) + (255,))
    end.save(out / "bar_w.png", optimize=True)
    end.save(out / "bar_e.png", optimize=True)
    hl = Image.new("RGBA", (1, ph), (0, 0, 0, 0))
    for y in range(1, gs + 1):
        hl.putpixel((0, y), rgb(P["accent"]) + (255,))
    hl.save(out / "hl_c.png", optimize=True)
    for part in ("c", "n", "s", "e", "w", "nw", "ne", "sw", "se"):
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(out / f"term_{part}.png", optimize=True)
    item_h, pad = 24 * gs, 8 * gs
    bw, bh = MENU_W + 2 * pad + 4 * gs * 2, len(MENU) * item_h + 2 * pad
    (out / "theme.txt").write_text(f"""# the boot menu of the fedokawaii installer (tools/build-iso-art.py): PNG words, no font
desktop-color: "#{P['ground']}"
title-text: ""
terminal-box: "term_*.png"
terminal-left: "50%-490"
terminal-top: "100%-770"
terminal-width: "980"
terminal-height: "530"

+ image {{
    left = 0 top = 100%-240
    file = "hem.png"
}}
+ image {{
    left = 50%-44 top = 50%-{bh // 2 + 120}
    file = "torii.png"
}}
+ boot_menu {{
    left = 50%-{bw // 2} top = 50%-{bh // 2} width = {bw} height = {bh}
    menu_pixmap_style = "menu_*.png"
    selected_item_pixmap_style = "select_*.png"
    item_height = {item_h} item_padding = {pad} item_spacing = 0
    item_icon_space = 0 icon_width = {MENU_W} icon_height = 28
    scrollbar = false
}}
+ progress_bar {{
    id = "__timeout__"
    left = 50%-{bw // 2} top = 50%+{bh // 2 + 4 * gs - 1} width = {bw} height = {ph}
    bar_style = "bar_*.png" highlight_style = "hl_*.png"
}}
""", encoding="utf-8")


def plymouth(out):
    out.mkdir(parents=True, exist_ok=True)
    src = ROOT / "system/plymouth/sumi"
    for f in sorted(src.iterdir()):
        (out / f.name).write_bytes(f.read_bytes())
    # the words under the torii: our name (the theme keeps the rest)
    w = int(UI.getlength("fedokawaii"))
    asc, desc = UI.getmetrics()
    im = Image.new("RGBA", (w, asc + desc), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((0, 0), "fedokawaii", font=UI, fill=rgb(P["muted"]))
    im.save(out / "starting.png", optimize=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "ground").write_text(P["ground"], encoding="ascii")
    n = console(out / "console")
    grub(out / "grub")
    plymouth(out / "plymouth")
    print(f"build-iso-art: {n} console glyphs, the menu, the splash in {out}")


main()
