#!/usr/bin/env python3
"""tools/build-art.py — draw the lock and login screens' pictures for both themes.

    FUSION_TTF=/path/to/fusion-pixel-12px-monospaced-ja.ttf python3 tools/build-art.py

Writes (committed, so installing needs neither Python nor Pillow):
    configs/home/.local/share/fedokawaii/<theme>/padlock.png   the pixel padlock (18 × 19
        cells of 6 px: square pixels, shown 1:1, so every edge is sharp)
    configs/home/.local/share/fedokawaii/<theme>/seal-1.png … seal-7.png   the weekday's
        kanji (月 火 水 木 金 土 日, Monday first, as `date +%u` counts) as a heading's seal,
        the one that opens the lock and login screens' panel: 23 px square, a 1 px edge2
        frame, the kanji in accent_text in Fusion Pixel at 12 px (its own grid: crisp)
    system/plymouth/sumi/*.png   the boot splash's pictures (always ink-dark, like the boot
        menu): the torii (art/grub/torii.xpm, 8× — the size the boot menu shows it at 1080p),
        "起動中 · starting Fedora" (and, as the machine goes down, "終了中 · shutting down" or
        "再起動中 · restarting"), the three dots that take turns while it waits, and for a
        disk password: its words, the box, the ◆ each typed character becomes
    src/kawa-saver/glyphs.h   the screensaver's letters: its kanji (the seals it stamps, 時
        for its clock), the digits and the clock's few letters, each as Fusion Pixel draws it
        at 12 px — a bitmap a row, for the C program to draw dot by dot
    art/gtklock.mo   gtklock's two messages in the desktop's words ("Login failed" →
        "ちがう · wrong password", "Caps Lock is on" → "Caps Lock · 大文字"), a message
        catalogue for a language of its own ("fk": no package has one), which kawa-lock
        asks for (LANGUAGE=fk); setup installs it as /usr/share/locale/fk/LC_MESSAGES/gtklock.mo
The colours come from tools/build-themes.py's palettes (imported), so a colour changed
there is changed here at the next run.
Needs: Pillow (dnf install python3-pillow) and the Fusion Pixel font file.
"""
import os
import pathlib
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.dont_write_bytecode = True            # (importing build-themes.py leaves no __pycache__ in the repo)
import importlib.util  # noqa: E402

spec = importlib.util.spec_from_file_location("themes", ROOT / "tools/build-themes.py")
themes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themes)
P = themes.P
OUT = ROOT / "configs/home/.local/share/fedokawaii"
KANJI = "月火水木金土日"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# the padlock, cell by cell: S shackle, T the lit top edge, B body, K keyhole, D the shadowed
# bottom edge. Every cell is a CELL × CELL square of one colour — retro, crisp at 1:1
PADLOCK = """
.....########.....
...############...
..####......####..
..###........###..
..###........###..
..###........###..
..###........###..
..###........###..
TTTTTTTTTTTTTTTTTT
BBBBBBBBBBBBBBBBBB
BBBBBBBBKKBBBBBBBB
BBBBBBBKKKKBBBBBBB
BBBBBBBKKKKBBBBBBB
BBBBBBBBKKBBBBBBBB
BBBBBBBBKKBBBBBBBB
BBBBBBBBKKBBBBBBBB
BBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBB
DDDDDDDDDDDDDDDDDD
""".split()
CELL = 2                                  # (36 × 38: the glyph beside the big clock)


def padlock(p):
    """36 × 38: the pixel padlock — 18 × 19 cells of 2 px, no smoothing (beside the clock)."""
    ink = {"#": p["muted"], "T": p["lit_hi"], "B": p["lit"], "K": p["ground"], "D": p["lit_lo"]}
    im = Image.new("RGBA", (len(PADLOCK[0]) * CELL, len(PADLOCK) * CELL), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y, row in enumerate(PADLOCK):
        for x, c in enumerate(row):
            if c in ink:
                d.rectangle([x * CELL, y * CELL, x * CELL + CELL - 1, y * CELL + CELL - 1], fill=rgb(ink[c]))
    return im


SEAL = 23                                 # a heading's seal (docs/design-system.md, kawa-panel)


def seal(p, ch, font):
    """23 × 23, a heading's seal as the panels draw it: a 1 px frame in edge2, the kanji in
    accent_text, its ink centred (6 px all round), pixel-exact (no smoothing); the ground
    clear, so the panel's surface shows through."""
    im = Image.new("RGBA", (SEAL, SEAL), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SEAL - 1, SEAL - 1], outline=rgb(p["edge2"]) + (255,))
    # the kanji's ink — drawn once on its own and measured pixel by pixel (the font's box has
    # the glyph's side bearings in it: centred by that, a kanji sits 1–2 px to the left)
    ink = Image.new("1", (SEAL * 2, SEAL * 2), 0)
    dk = ImageDraw.Draw(ink)
    dk.fontmode = "1"                     # whole pixels only: the font is a pixel font
    dk.text((SEAL // 2, SEAL // 2), ch, font=font, fill=1)
    l, t, r, b = ink.getbbox()            # (r, b: one past the ink)
    x = (SEAL - (r - l)) // 2 - l + SEAL // 2
    y = (SEAL - (b - t)) // 2 - t + SEAL // 2
    d.fontmode = "1"
    d.text((x, y), ch, font=font, fill=rgb(p["accent_text"]) + (255,))
    return im


MESSAGES = {"Login failed": "ちがう · wrong password", "Caps Lock is on": "Caps Lock · 大文字"}


def mo(messages):
    """A GNU message catalogue (.mo): the header entry, then the messages, sorted."""
    items = sorted({"": "Content-Type: text/plain; charset=UTF-8\n", **messages}.items())
    ids = [k.encode() for k, _ in items]
    strs = [v.encode() for _, v in items]
    n = len(items)
    start = 7 * 4 + 16 * n                 # header, then the two tables of (length, offset)
    data, otab, ttab = b"", [], []
    for b in ids:
        otab.append((len(b), start + len(data)))
        data += b + b"\0"
    for b in strs:
        ttab.append((len(b), start + len(data)))
        data += b + b"\0"
    head = struct.pack("<7I", 0x950412DE, 0, n, 7 * 4, 7 * 4 + 8 * n, 0, 0)
    return head + b"".join(struct.pack("<2I", *e) for e in otab + ttab) + data


def xpm(path):
    """A small XPM (one character per pixel, colours or None) as an RGBA picture."""
    import re
    rows = re.findall(r'"([^"]*)"', path.read_text())
    w, h, ncol, _ = map(int, rows[0].split())
    colours = {}
    for line in rows[1:1 + ncol]:
        key, value = line[0], line.split()[-1]
        colours[key] = (0, 0, 0, 0) if value == "None" else rgb(value.lstrip("#")) + (255,)
    im = Image.new("RGBA", (w, h))
    for y, row in enumerate(rows[1 + ncol:1 + ncol + h]):
        for x, c in enumerate(row):
            im.putpixel((x, y), colours[c])
    return im


def text_png(font, parts, pad=0):
    """Words in Fusion Pixel, pixel-exact: parts is [(text, colour), …] side by side."""
    w = sum(int(font.getlength(t)) for t, _ in parts)
    asc, desc = font.getmetrics()
    im = Image.new("RGBA", (w + 2 * pad, asc + desc + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    x = pad
    for t, c in parts:
        d.text((x, pad), t, font=font, fill=rgb(c))
        x += int(font.getlength(t))
    return im


def splash(font):
    """The boot splash's pictures, in the dark palette (the boot is always ink)."""
    p = P["dark"]
    out = ROOT / "system/plymouth/sumi"
    out.mkdir(parents=True, exist_ok=True)
    torii = xpm(ROOT / "art/grub/torii.xpm")
    torii.resize((torii.width * 8, torii.height * 8), Image.NEAREST).save(out / "torii.png", optimize=True)
    text_png(font, [("起動中", p["text"]), (" · starting Fedora", p["muted"])]).save(out / "starting.png", optimize=True)
    text_png(font, [("終了中", p["text"]), (" · shutting down", p["muted"])]).save(out / "stopping.png", optimize=True)
    text_png(font, [("再起動中", p["text"]), (" · restarting", p["muted"])]).save(out / "restarting.png", optimize=True)
    text_png(font, [("パスワード", p["text"]), (" · the disk's password", p["muted"])]).save(out / "password.png", optimize=True)
    for name, c in (("dot-on", p["accent"]), ("dot-off", p["edge2"])):
        Image.new("RGBA", (6, 6), rgb(c) + (255,)).save(out / f"{name}.png", optimize=True)
    box = Image.new("RGBA", (288, 44), rgb(p["edge2"]) + (255,))      # the lock screen's box
    ImageDraw.Draw(box).rectangle([2, 2, 285, 41], fill=rgb(p["surface"]))
    box.save(out / "box.png", optimize=True)
    d = text_png(font, [("◆", p["accent"])])
    d.crop(d.getbbox()).save(out / "diamond.png", optimize=True)      # (its ink alone: the script spaces them)
    return 10


SAVER_KANJI = "縫糸針夢眠静月星夜波雪花灯風"    # the seals kawa-saver stamps (sewing, sleep, night)
SAVER_TEXT = "時0123456789: APM"                   # its clock: the seal, "09:41 PM"


def saver_glyphs(font):
    """src/kawa-saver/glyphs.h: each character as the font draws it at 12 px, pixel-exact —
    12 rows, a bit a pixel (the leftmost the highest), 12 wide (kanji) or 6 (the rest)."""
    lines = ["/* src/kawa-saver/glyphs.h — generated by tools/build-art.py (Fusion Pixel at 12 px); do not edit */",
             "struct glyph { const char *ch; int w; unsigned short rows[12]; };",
             "static const struct glyph glyphs[] = {"]
    for ch in SAVER_KANJI + SAVER_TEXT:
        w = int(font.getlength(ch))
        im = Image.new("1", (w, 12), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        d.text((0, 0), ch, font=font, fill=1)
        rows = [sum(1 << (w - 1 - x) for x in range(w) if im.getpixel((x, y))) for y in range(12)]
        lines.append(f'\t{{ "{ch}", {w}, {{ {", ".join(f"0x{r:03x}" for r in rows)} }} }},')
    lines += ["};", f'static const char saver_kanji[] = "{SAVER_KANJI}";', ""]
    (ROOT / "src/kawa-saver/glyphs.h").write_text("\n".join(lines))


def main():
    ttf = os.environ.get("FUSION_TTF")
    if not ttf or not os.path.exists(ttf):
        sys.exit("set FUSION_TTF to fusion-pixel-12px-monospaced-ja.ttf (lib/upstream.sh fetches it)")
    font = ImageFont.truetype(ttf, 24)
    font12 = ImageFont.truetype(ttf, 12)
    n = 0
    for m, p in P.items():
        d = OUT / m
        d.mkdir(parents=True, exist_ok=True)
        padlock(p).save(d / "padlock.png", optimize=True)
        n += 1
        for i, ch in enumerate(KANJI, 1):
            seal(p, ch, font12).save(d / f"seal-{i}.png", optimize=True)
            n += 1
    n += splash(font)
    saver_glyphs(font12)
    (ROOT / "art/gtklock.mo").write_bytes(mo(MESSAGES))
    print(f"{n} pictures written, art/gtklock.mo and src/kawa-saver/glyphs.h")


if __name__ == "__main__":
    main()
