#!/usr/bin/env python3
"""tools/build-iso-art.py — the installer ISO's pictures, every one from the desktop's own sources.

    python3 tools/build-iso-art.py OUTDIR [VERSION]
    python3 tools/build-iso-art.py --console OUTDIR     the font and its names alone (the VM's reader)

Writes (tools/build-iso.sh calls it, with SOURCE_DATE_EPOCH set; nothing here reads the clock):
    OUTDIR/console/sumi-console.psf   Sumi UI ×2 (design system §2: the installer's screens) as a
        Linux console font, a 14 × 28 cell, with our icons, the head as a crest of 1-bit tiles and
        the screens' own tiles in the Private Use Area
    OUTDIR/console/glyphs.py          the names of those tiles, the palette's roles, for iso/screens/
    OUTDIR/grub/…                     the boot menu's theme: shiro, the castle at night (the lock's map) dimmed behind
        an ink plate, PNG only, words too (under Secure Boot Fedora's GRUB refuses any font but the
        Unifont inside its signed image: iso-research.md §5)
    OUTDIR/plymouth/…                 the boot splash of the first stage: system/plymouth/sumi
    OUTDIR/ground                     the ground's colour, for iso/grub.cfg
Needs: Pillow. Colours from tools/build-themes.py's dark palette: the boot is always ink.
"""
import importlib.util
import pathlib
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
SCENE = ROOT / "configs/home/.local/share/fedokawaii/dark/lock-map-shiro.png"  # the castle at night, 640 × 360
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


CREST_COLS, CREST_ROWS = 21, 9    # (the console keeps 256 glyphs: the largest whose different tiles still fit)


def crest():
    """The splash's head as the console can hold it, one ink: the bloody Fedora logo's own pixels ×5 (the disc and its
    blood; the f the air it encloses), centred on the tiles."""
    spec = importlib.util.spec_from_file_location("build_head", ROOT / "tools/build-head.py")
    head = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(head)
    disc, _ = head.silhouettes()[40]
    run, bead, _ = head.blood(40, disc, "shut")
    ink = disc | run | bead
    k = 5
    w, h = CREST_COLS * CELL_W, CREST_ROWS * CELL_H
    ox = (w - 40 * k) // 2
    oy = (h - (max(y for _, y in ink) + 1) * k) // 2
    im = Image.new("1", (w, h), 0)
    d = ImageDraw.Draw(im)
    for x, y in ink:
        d.rectangle([ox + x * k, oy + y * k, ox + x * k + k - 1, oy + y * k + k - 1], fill=1)
    return im


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
    # the head: a tile once however often it comes, an empty one the space
    seen, line = {}, []
    for t in tiles(crest(), CREST_COLS, CREST_ROWS):
        key = t.tobytes()
        if t.getbbox() is None:
            line.append(" ")
            continue
        if key not in seen:
            seen[key] = next_cp
            glyphs.append((t, [next_cp]))
            next_cp += 1
        line.append(chr(seen[key]))
    names["crest"] = "".join(line)
    # the meter (design system §7): segments, a cell each — solid, and hollow for what is to come
    add("seg_on", [icon("read", 1)])
    add("seg_off", [icon("read-off", 1)])
    (out / "sumi-console.psf").write_bytes(psf(glyphs))
    lines = ['"""the console font\'s tiles and the palette\'s roles (written by tools/build-iso-art.py)."""', "G = {"]
    lines += [f"    {k!r}: {v!r}," for k, v in sorted(names.items())]
    lines += ["}", f"CREST_COLS, CREST_ROWS = {CREST_COLS}, {CREST_ROWS}", "COLOURS = {"]
    roles = ("ground", "select", "surface", "accent", "edge2", "edge", "edge", "text",       # (0–7: inks and grounds)
             "faint", "muted", "text", "strong", "accent_text", "asagi", "gold", "text_on_select")
    lines += [f"    {i}: {P[r]!r},  # {r}" for i, r in enumerate(roles)]
    lines += ["}", ""]
    (out / "glyphs.py").write_text("\n".join(lines), encoding="utf-8")
    return len(glyphs)


MENU = (("fkinstall", "install fedokawaii"),
        ("fkcheck", "check this stick, then install"),
        ("fkoff", "turn the PC off"))        # (three lines: GRUB's list is never shorter than three rows)
MENU_W = 14 * 31                 # the longest entry's letters and one more, whole letters


def words(text, colour, scale=2, width=None):
    """Words in Sumi UI, whole pixels on nothing; every letter 7 px wide, so width is known by count."""
    small = Image.new("1", (7 * len(text), 14), 0)
    d = ImageDraw.Draw(small)
    d.fontmode = "1"
    d.text((0, 0), text, font=UI, fill=1)
    im = Image.new("RGBA", (width or small.width * scale, 14 * scale), (0, 0, 0, 0))
    c = Image.new("RGBA", (small.width * scale, 14 * scale), rgb(colour) + (255,))
    im.paste(c, (0, 0), small.resize(c.size, Image.NEAREST))
    return im


EDGE = 2


def solid(path, w, h, colour):
    Image.new("RGB", (w, h), rgb(colour)).save(path, optimize=True)


def backdrop(path):
    """The castle at night at a quarter of its light, on the ground's ink so it never goes blacker
    than the screens around it. Whole pixels, ×3."""
    im = Image.open(SCENE).convert("RGB").resize((1920, 1080), Image.NEAREST)
    lut = []
    for g in rgb(P["ground"]):
        lut += [round(g + v * 0.25 * (1 - g / 255)) for v in range(256)]
    im.point(lut).save(path, optimize=True)


def line(path, h, colour):
    """GRUB's progress bar is as tall as its text would be: the line is its first rows, the rest nothing."""
    im = Image.new("RGBA", (1, h), (0, 0, 0, 0))
    for y in range(EDGE):
        im.putpixel((0, y), rgb(colour) + (255,))
    im.save(path, optimize=True)


def foot(path, text, w, h):
    """The plate's lower part, seamless with it: ground, the side and lower edges, the keys' words centred."""
    im = Image.new("RGBA", (w, h), rgb(P["accent"]) + (255,))
    ImageDraw.Draw(im).rectangle([EDGE, 0, w - EDGE - 1, h - EDGE - 1], fill=rgb(P["ground"]))
    t = words(text, P["muted"])
    im.alpha_composite(t, ((w - t.width) // 2, (h - t.height) // 2 - 1))
    im.save(path, optimize=True)


PLATE_W, PLATE_TOP, FOOT_H = 640, 144, 44     # a third of the screen, from 144 px under its middle: on the mouth, the eyes above it


def grub(out, version):
    (out / "icons").mkdir(parents=True, exist_ok=True)
    gs = 2
    for cls, text in MENU:
        words(text, P["strong"], width=MENU_W).save(out / "icons" / f"{cls}.png", optimize=True)
    backdrop(out / "backdrop.png")
    solid(out / "menu_c.png", 1, 1, P["ground"])
    for part, w, h in (("n", 1, EDGE), ("s", 1, EDGE), ("e", EDGE, 1), ("w", EDGE, 1),
                       ("nw", EDGE, EDGE), ("ne", EDGE, EDGE), ("sw", EDGE, EDGE), ("se", EDGE, EDGE)):
        solid(out / f"menu_{part}.png", w, h, P["accent"])
    solid(out / "select_c.png", 1, 1, P["select"])
    for part in ("w", "e"):
        solid(out / f"select_{part}.png", 4 * gs, 1, P["select"])
    ph = 14 * gs
    for part in ("c", "w", "e"):
        line(out / f"bar_{part}.png", ph, P["accent"])
        line(out / f"hl_{part}.png", ph, P["accent_text"])
    for part in ("c", "n", "s", "e", "w", "nw", "ne", "sw", "se"):
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(out / f"term_{part}.png", optimize=True)
    item_h, pad = 24 * gs, 8 * gs
    bh = len(MENU) * item_h + 2 * pad + 2 * EDGE
    foot(out / "foot.png", "↑↓ choose · enter go", PLATE_W, FOOT_H)
    stamp = words(version, P["muted"], scale=1) if version else None
    if stamp:
        stamp.save(out / "version.png", optimize=True)
    foot_top = PLATE_TOP + bh
    # (GRUB's terminal, the window it paints black as an entry starts and keeps up while the kernel unpacks
    # its initrd: the smallest GRUB takes, in a corner, so the picture stays until the splash takes over,
    # under Secure Boot too)
    (out / "theme.txt").write_text(f"""# the boot menu of the fedokawaii installer (tools/build-iso-art.py): PNG words, no font
desktop-image: "backdrop.png"
desktop-color: "#{P['ground']}"
title-text: ""
terminal-box: "term_*.png"
terminal-left: "0"
terminal-top: "100%-32"
terminal-width: "16"
terminal-height: "32"

+ boot_menu {{
    left = 50%-{PLATE_W // 2} top = 50%+{PLATE_TOP} width = {PLATE_W} height = {bh}
    menu_pixmap_style = "menu_*.png"
    selected_item_pixmap_style = "select_*.png"
    item_height = {item_h} item_padding = {pad} item_spacing = 0
    item_icon_space = 0 icon_width = {MENU_W} icon_height = 28
    scrollbar = false
}}
+ image {{
    left = 50%-{PLATE_W // 2} top = 50%+{foot_top}
    file = "foot.png"
}}
+ progress_bar {{
    id = "__timeout__"
    left = 50%-{PLATE_W // 2} top = 50%+{foot_top - EDGE} width = {PLATE_W} height = {ph}
    bar_style = "bar_*.png" highlight_style = "hl_*.png"
}}
""" + (f"""+ image {{
    left = 100%-{stamp.width + 24} top = 100%-{stamp.height + 16}
    file = "version.png"
}}
""" if stamp else ""), encoding="utf-8")


def plymouth(out):
    out.mkdir(parents=True, exist_ok=True)
    src = ROOT / "system/plymouth/sumi"
    for f in sorted(src.iterdir()):
        (out / f.name).write_bytes(f.read_bytes())


def main():
    args = sys.argv[1:]
    only_console = args[:1] == ["--console"]
    args = args[1:] if only_console else args
    if not 1 <= len(args) <= 2:
        sys.exit(__doc__)
    out = pathlib.Path(args[0])
    out.mkdir(parents=True, exist_ok=True)
    (out / "ground").write_text(P["ground"], encoding="ascii")
    n = console(out / "console")
    if not only_console:
        grub(out / "grub", args[1] if len(args) == 2 else "")
        plymouth(out / "plymouth")
    print(f"build-iso-art: {n} console glyphs in {out}")


main()
