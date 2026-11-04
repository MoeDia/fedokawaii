#!/usr/bin/env python3
"""tools/build-art.py — draw the boot splash's pictures, the screensaver's letters and the lock's
words (the lock's and login's scenes are tools/build-lock.py's).

    python3 tools/build-art.py

Writes (committed, so installing needs neither Python nor Pillow):
    system/plymouth/sumi/*.png   the boot splash's pictures (always ink-dark, like the boot
        menu), around mask.png (the demon cut from the dark lock's painting, not made here):
        "fedokawaii" (and, as the machine goes down, "shutting down" or "restarting") in Sumi UI
        ×3 — no kanji: the desktop keeps them to the workspace stamps, the lock's quote and the
        clock's day — the slim line with its ember, and for a disk password: its words, the box,
        the ◆ each typed character becomes
    src/kawa-saver/glyphs.h   the screensaver's letters: the seals it stamps (the night's own
        pictures from art/icons.txt: moon, zzz, lantern…), its clock's seal (the day's kanji, as
        the bar's clock has it), the digits and the clock's few letters as Sumi UI draws them at
        14 px — a bitmap a row, for the C program to draw dot by dot
    art/gtklock.mo   gtklock's two messages in the desktop's words ("Login failed" →
        "wrong password", "Caps Lock is on" → "Caps Lock"; seen only on a lock without its
        module — the scene says both), a message
        catalogue for a language of its own ("fk": no package has one), which kawa-lock
        asks for (LANGUAGE=fk); setup installs it as /usr/share/locale/fk/LC_MESSAGES/gtklock.mo
The colours come from tools/build-themes.py's palettes (imported), so a colour changed
there is changed here at the next run.
Needs: Pillow (dnf install python3-pillow). The letters: Sumi UI (system/fonts/SumiUI.ttf).
"""
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


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


MESSAGES = {"Login failed": "wrong password", "Caps Lock is on": "Caps Lock"}


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


def text_png(font, parts, pad=0):
    """Words in Sumi UI, pixel-exact: parts is [(text, colour), …] side by side."""
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
    def big(text, colour, n=3):
        """Display size: Sumi UI at 14, ×3, each letter set by its own ink (a cell's air would let the i's float)."""
        small = ImageFont.truetype(font.path, 14)
        letters = []
        for ch in text:
            im = text_png(small, [(ch, colour)])
            box = im.getbbox()
            letters.append(im.crop((box[0], 0, box[2], im.height)) if box else Image.new("RGBA", (3, im.height)))
        im = Image.new("RGBA", (sum(ch.width for ch in letters) + 2 * (len(letters) - 1), letters[0].height))
        x = 0
        for ch in letters:
            im.paste(ch, (x, 0))
            x += ch.width + 2
        return im.resize((im.width * n, im.height * n), Image.NEAREST)

    big("fedokawaii", p["text"]).save(out / "starting.png", optimize=True)
    big("shutting down", p["text"]).save(out / "stopping.png", optimize=True)
    big("restarting", p["text"]).save(out / "restarting.png", optimize=True)
    text_png(font, [("the disk's password", p["muted"])]).save(out / "password.png", optimize=True)
    Image.new("RGBA", (320, 2), rgb(p["edge2"]) + (255,)).save(out / "line-off.png", optimize=True)
    Image.new("RGBA", (1, 2), rgb(p["accent"]) + (255,)).save(out / "line-on.png", optimize=True)
    ember = Image.new("RGBA", (48, 2), (0, 0, 0, 0))      # (a coal on the line: a tail that fades, its head bright)
    for x in range(48):
        for y in (0, 1):
            ember.putpixel((x, y), rgb(p["accent"]) + (round(255 * ((x + 1) / 48) ** 2),))
    ember.save(out / "ember.png", optimize=True)
    box = Image.new("RGBA", (288, 44), rgb(p["edge2"]) + (255,))      # the lock screen's box
    ImageDraw.Draw(box).rectangle([2, 2, 285, 41], fill=rgb(p["surface"]))
    box.save(out / "box.png", optimize=True)
    d = text_png(font, [("◆", p["accent"])])
    d.crop(d.getbbox()).save(out / "diamond.png", optimize=True)      # (its ink alone: the script spaces them)
    return 10


SAVER_SEALS = ("moon", "zzz", "lantern", "cloud", "fog", "snow", "music")   # the seals kawa-saver stamps:
# the night's own pictures (art/icons.txt) — kanji stay where he kept them: the stamps, the lock's quote, the day
SAVER_DAYS = "日月火水木金土"                   # its clock's seal: the day's, as the bar's clock (tm_wday: Sunday 0)
SAVER_TEXT = "0123456789: APM"                  # its clock: "09:41 PM"


def icon_rows(name):
    """an icon of art/icons.txt as a 14 × 14 glyph: its 12 × 12 drawing on the em's rows 1–12, one column of air
    either side (where it sits beside words: the seal centres its ink anyway)"""
    rows, on = [], False
    for line in (ROOT / "art/icons.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("@"):
            if on:
                break
            on = line.split()[0] == "@" + name
        elif on and line and set(line) <= set("#."):
            rows.append(line)
    if not rows or len(rows) > 12 or max(map(len, rows)) > 12:
        sys.exit(f"build-art: icon {name}: not a 12 × 12 drawing in art/icons.txt")
    out = [0] * 14
    for y, line in enumerate(rows):
        out[1 + y] = sum(1 << (14 - 2 - x) for x, c in enumerate(line) if c == "#")
    return out


def saver_glyphs(font):
    """src/kawa-saver/glyphs.h: the seals' pictures (art/icons.txt, 14 × 14), the days' kanji and the clock's
    letters as the font draws them at 14 px, pixel-exact — 14 rows, a bit a pixel (the leftmost the highest),
    14 wide (a picture, a kanji) or 7 (the rest)."""
    lines = ["/* src/kawa-saver/glyphs.h — generated by tools/build-art.py (art/icons.txt; Sumi UI at 14 px); do not edit */",
             "#define GLYPH_H 14      /* a line of Sumi UI */",
             "#define GLYPH_COL 7     /* a column: a letter (a kanji two) */",
             "struct glyph { const char *ch; int w; unsigned short rows[GLYPH_H]; };",
             "static const struct glyph glyphs[] = {"]
    for name in SAVER_SEALS:
        lines.append(f'\t{{ "{name}", 14, {{ {", ".join(f"0x{r:04x}" for r in icon_rows(name))} }} }},')
    for ch in SAVER_DAYS + SAVER_TEXT:
        w = int(font.getlength(ch))
        im = Image.new("1", (w, 14), 0)
        d = ImageDraw.Draw(im)
        d.fontmode = "1"
        d.text((0, 0), ch, font=font, fill=1)
        rows = [sum(1 << (w - 1 - x) for x in range(w) if im.getpixel((x, y))) for y in range(14)]
        lines.append(f'\t{{ "{ch}", {w}, {{ {", ".join(f"0x{r:04x}" for r in rows)} }} }},')
    lines += ["};", "static const char *const saver_seals[] = { " + ", ".join(f'"{n}"' for n in SAVER_SEALS) + " };",
              f'static const char saver_days[] = "{SAVER_DAYS}";', ""]
    (ROOT / "src/kawa-saver/glyphs.h").write_text("\n".join(lines))


def main():
    ttf = ROOT / "system/fonts/SumiUI.ttf"
    font = ImageFont.truetype(str(ttf), 28)
    font14 = ImageFont.truetype(str(ttf), 14)
    n = splash(font)
    saver_glyphs(font14)
    (ROOT / "art/gtklock.mo").write_bytes(mo(MESSAGES))
    print(f"{n} pictures written, art/gtklock.mo and src/kawa-saver/glyphs.h")


if __name__ == "__main__":
    main()
