#!/usr/bin/env python3
"""tools/build-cursors.py — build the desktop's mouse pointers from art/cursors.txt.

    python3 tools/build-cursors.py                    # writes the cursor theme
    python3 tools/build-cursors.py --preview out.png  # also draws every pointer, 8x, centred

Output (committed, so a normal install needs no Python):
    configs/home/.local/share/icons/Fedokawai/cursors/<name>   Xcursor files, 24 and 48 px
    configs/home/.local/share/icons/Fedokawai/index.theme

Every pointer comes in two sizes in one file: 24 px, drawn 1:1 (the desktop's own pixel
scale, like its fonts and icons), and 48 px with every pixel doubled for 2x screens. The
compositor picks the one for its size (dwl asks for 24; a 2x screen gets 48). The other
names programs ask for (left_ptr, hand2, xterm…) are links theme.sh makes; names that are
not drawn here come from Adwaita (index.theme: Inherits).
Standard library only.
"""
import argparse
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "cursors.txt"
OUT = ROOT / "configs/home/.local/share/icons/Fedokawai"
COLOURS = {"K": 0xFF0F0E0C, "W": 0xFFECE3CC, "R": 0xFFD0583A}   # ARGB, opaque
SIZES = (24, 48)                                                 # nominal sizes: 1x and 2x


def parse(text):
    cursors, cur = [], None
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if cur is None and (line == "#" or line.startswith("# ")):
            continue
        if line.startswith("@"):
            m = re.fullmatch(r"@([a-z][a-z-]*) hot=(\d+),(\d+)( halo)?", line)
            if not m:
                sys.exit(f"cursors.txt:{n}: bad header {line!r}")
            cur = {"name": m[1], "hot": (int(m[2]), int(m[3])), "halo": bool(m[4]), "rows": [], "line": n}
            cursors.append(cur)
        elif re.fullmatch(r"[.KWR]+", line):
            if cur is None:
                sys.exit(f"cursors.txt:{n}: drawing outside a pointer")
            cur["rows"].append(line)
        elif not line:
            cur = None
        else:
            sys.exit(f"cursors.txt:{n}: unknown characters in {line!r}")
    for c in cursors:
        widths = {len(r) for r in c["rows"]}
        if len(widths) != 1:
            sys.exit(f"cursors.txt:{c['line']}: {c['name']} rows differ in width {sorted(widths)}")
        c["w"], c["h"] = widths.pop(), len(c["rows"])
        x, y = c["hot"]
        if not (0 <= x < c["w"] and 0 <= y < c["h"]):
            sys.exit(f"cursors.txt:{c['line']}: {c['name']} hotspot outside the drawing")
    return cursors


def pixels(c):
    """The drawing as rows of ARGB, a 1-pixel paper rim added round a halo drawing."""
    rows = [[COLOURS.get(ch, 0) for ch in r] for r in c["rows"]]
    hx, hy = c["hot"]
    if c["halo"]:
        w, h = c["w"] + 2, c["h"] + 2
        out = [[0] * w for _ in range(h)]
        for y in range(c["h"]):
            for x in range(c["w"]):
                if rows[y][x]:
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            out[y + 1 + dy][x + 1 + dx] = out[y + 1 + dy][x + 1 + dx] or COLOURS["W"]
        for y in range(c["h"]):
            for x in range(c["w"]):
                if rows[y][x]:
                    out[y + 1][x + 1] = rows[y][x]
        rows, hx, hy = out, hx + 1, hy + 1
    return rows, hx, hy


def xcursor(c):
    """One Xcursor file: a table of contents, then one image chunk per size."""
    rows, hx, hy = pixels(c)
    chunks = []
    for size in SIZES:
        k = size // SIZES[0]
        w, h = len(rows[0]) * k, len(rows) * k
        data = b"".join(struct.pack("<I", rows[y // k][x // k]) for y in range(h) for x in range(w))
        chunks.append((size, struct.pack("<9I", 36, 0xFFFD0002, size, 1, w, h, hx * k, hy * k, 0) + data))
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(chunks))
    pos = len(head) + 12 * len(chunks)
    toc, body = b"", b""
    for size, chunk in chunks:
        toc += struct.pack("<III", 0xFFFD0002, size, pos + len(body))
        body += chunk
    return head + toc + body


def preview(cursors, path, scale=8):
    """A sheet: every pointer centred to the pixel in a cell of its own (scale even, so
    the centring is exact), on ink above and on paper below — the drawings alone."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        sys.exit("--preview needs python3-pillow")
    grid = 23                                   # cell size in drawing pixels (the largest is 21)
    cell, gap, label = grid * scale, 6, 34
    font = None
    for f in ("/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if pathlib.Path(f).exists():
            font = ImageFont.truetype(f, 18)
            break
    n = len(cursors)
    sheet = Image.new("RGB", (n * cell + (n + 1) * gap, 2 * cell + 3 * gap + label), (110, 106, 98))
    d = ImageDraw.Draw(sheet)
    for i, c in enumerate(cursors):
        rows, _, _ = pixels(c)
        ink = [(x, y) for y, r in enumerate(rows) for x, v in enumerate(r) if v]   # centred by what is drawn
        l, t = min(x for x, _ in ink), min(y for _, y in ink)
        w, h = max(x for x, _ in ink) - l + 1, max(y for _, y in ink) - t + 1
        x0 = gap + i * (cell + gap)
        for band, ground in enumerate(((15, 14, 12), (233, 225, 203))):
            y0 = gap + band * (cell + gap)
            d.rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], fill=ground)
            ox, oy = x0 + (cell - w * scale) // 2 - l * scale, y0 + (cell - h * scale) // 2 - t * scale
            for x, y in ink:
                v = rows[y][x]
                d.rectangle([ox + x * scale, oy + y * scale, ox + (x + 1) * scale - 1, oy + (y + 1) * scale - 1],
                            fill=((v >> 16) & 255, (v >> 8) & 255, v & 255))
        tw = d.textlength(c["name"], font=font) if font else 6 * len(c["name"])
        d.text((x0 + (cell - tw) / 2, 2 * cell + 2 * gap + 8), c["name"], fill=(245, 241, 232), font=font)
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", metavar="PNG")
    a = ap.parse_args()
    cursors = parse(SRC.read_text())
    (OUT / "cursors").mkdir(parents=True, exist_ok=True)
    for c in cursors:
        (OUT / "cursors" / c["name"]).write_bytes(xcursor(c))
    (OUT / "index.theme").write_text(
        "[Icon Theme]\n"
        "Name=Fedokawai\n"
        "Comment=Pixel pointers in ink and paper (tools/build-cursors.py)\n"
        "Inherits=Adwaita\n")
    print(f"{len(cursors)} pointers → {(OUT / 'cursors').relative_to(ROOT)}/")
    if a.preview:
        preview(cursors, a.preview)


if __name__ == "__main__":
    main()
