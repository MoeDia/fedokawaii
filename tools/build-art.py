#!/usr/bin/env python3
"""tools/build-art.py — draw the boot splash's pictures, the screensaver's letters and the lock's
words (the lock's and login's scenes are tools/build-lock.py's).

    python3 tools/build-art.py

Writes (committed, so installing needs neither Python nor Pillow):
    system/plymouth/sumi/*.png   the boot splash's pictures (always ink-dark, like the boot
        menu): the torii (art/grub/torii.xpm, 8× — the size the boot menu shows it at 1080p),
        "starting Fedora" (and, as the machine goes down, "shutting down" or "restarting"),
        quiet, in muted — no kanji: the desktop keeps them to the workspace stamps, the lock's
        quote and the clock's day — the three dots that take turns while it waits, and for a
        disk password: its words, the box, the ◆ each typed character becomes
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
    torii = xpm(ROOT / "art/grub/torii.xpm")
    torii.resize((torii.width * 8, torii.height * 8), Image.NEAREST).save(out / "torii.png", optimize=True)
    text_png(font, [("starting Fedora", p["muted"])]).save(out / "starting.png", optimize=True)
    text_png(font, [("shutting down", p["muted"])]).save(out / "stopping.png", optimize=True)
    text_png(font, [("restarting", p["muted"])]).save(out / "restarting.png", optimize=True)
    text_png(font, [("the disk's password", p["muted"])]).save(out / "password.png", optimize=True)
    for name, c in (("dot-on", p["accent"]), ("dot-off", p["edge2"])):
        Image.new("RGBA", (6, 6), rgb(c) + (255,)).save(out / f"{name}.png", optimize=True)
    box = Image.new("RGBA", (288, 44), rgb(p["edge2"]) + (255,))      # the lock screen's box
    ImageDraw.Draw(box).rectangle([2, 2, 285, 41], fill=rgb(p["surface"]))
    box.save(out / "box.png", optimize=True)
    d = text_png(font, [("◆", p["accent"])])
    d.crop(d.getbbox()).save(out / "diamond.png", optimize=True)      # (its ink alone: the script spaces them)
    return 10




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


def main():
    ttf = ROOT / "system/fonts/SumiUI.ttf"
    font = ImageFont.truetype(str(ttf), 28)
    n = splash(font)
    (ROOT / "art/gtklock.mo").write_bytes(mo(MESSAGES))
    print(f"{n} pictures written, art/gtklock.mo")


if __name__ == "__main__":
    main()
