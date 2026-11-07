#!/usr/bin/env python3
"""tools/build-head.py — the head: the Fedora logo, bloody in the dark mood, lighty in the light (the owner, 6 Nov:
"no demon or angel head anywhere"; only the wallpapers keep those). Pixel art, placed by hand: the silhouettes in
art/fedora-head.txt, the blood and the light below; one drawing a size, never a downscale.

    python3 tools/build-head.py [--sheet DIR]

    art/icons.txt @head-*                     the prompt's glyphs, one ink, 24 × 20 (16 + 8 wide)
    themes/MOOD/head-32.png, head-32-open.png the bar's end tile, 32 × 30 (the paper's rows), the disc 26 across
    themes/MOOD/head-48.png, head-48-open.png quick settings' masthead
    .local/share/fedokawaii/MOOD/head.six     fetch's picture: the 48 at 6 × 6, 288 × 300, 36 cells × 15 lines

At rest the blood hangs and the light is a few still points. Open (the panel, a failed command): the blood runs, a
drop has let go; the light spreads. Needs Pillow.
"""
import argparse
import pathlib
import re

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
THEMES = ROOT / "configs/home/.config/fedokawaii/themes"
SHARE = ROOT / "configs/home/.local/share/fedokawaii"
ICONS = ROOT / "art/icons.txt"
MAPS = ROOT / "art/fedora-head.txt"
AIR = (0, 0, 0, 0)

# the inks (design system §2's vermilion and leaf, a blood and a sky of their own: art only)
BLOODY = {"disc": "bb2a1c", "shade": "82241f", "lit": "eb5324", "shine": "f47b58", "f": "f5ecc2", "f_shade": "c9b48a"}
LIGHTY = {"disc": "8cc4e6", "shade": "5d9cc6", "lit": "b4dcf2", "shine": "e4f4fb", "f": "fffdf2", "f_shade": "e4e6d6",
          "edge": "3f7ea8", "ray": "e2b540", "ray_lit": "f4d97a"}

# the blood, by hand: (column in the disc's map, how far below the disc it hangs); the drop that let go: (column, row
# below the disc). GLOSS: the wet shine on the disc's upper left. The light: runs of pixels from the canvas's own edge, (x, y, dx, dy, length, ink).
DRIPS = {
    16: {"shut": ((3, 1), (7, 2)), "open": ((3, 2), (7, 2), (11, 1)), "drop": None},
    26: {"shut": ((5, 1), (9, 2)), "open": ((5, 2), (9, 2), (13, 1), (18, 2)), "drop": (20, 3)},
    40: {"shut": ((8, 1), (14, 3), (29, 2)), "open": ((8, 3), (14, 3), (20, 1), (29, 5)), "drop": (34, 5)},
}
GLOSS = {16: ((4, 3), (5, 2)), 26: ((6, 8), (6, 7), (7, 6), (8, 5), (9, 4), (7, 7), (8, 6)), 40: ((9, 10), (9, 11), (10, 9), (11, 8), (12, 7), (13, 6), (14, 6), (10, 10), (11, 9), (12, 8), (13, 7))}
RAYS = {
    16: {"shut": ((1, 2, 1, 1, 1), (20, 2, -1, 1, 1), (0, 9, 1, 0, 2), (20, 9, 1, 0, 2)),
         "open": ((1, 1, 1, 1, 2), (20, 1, -1, 1, 2), (0, 9, 1, 0, 2), (20, 9, 1, 0, 2), (1, 16, 1, -1, 1), (20, 16, -1, -1, 1), (10, 1, 1, 0, 2), (10, 18, 1, 0, 2))},
    26: {"shut": ((0, 14, 1, 0, 2), (0, 15, 1, 0, 2), (30, 14, 1, 0, 2), (30, 15, 1, 0, 2),   # (none above or below: the paper's
                  (4, 3, 1, 1, 1), (27, 3, -1, 1, 1), (27, 26, -1, -1, 1)),                    #  edge rows touch the hairlines)
         "open": ((0, 13, 1, 0, 2), (0, 14, 1, 0, 2), (0, 15, 1, 0, 2), (0, 16, 1, 0, 2), (30, 13, 1, 0, 2), (30, 14, 1, 0, 2), (30, 15, 1, 0, 2), (30, 16, 1, 0, 2),
                  (3, 2, 1, 1, 2), (28, 2, -1, 1, 2), (28, 27, -1, -1, 2), (0, 8, 1, 0, 1), (31, 8, -1, 0, 1), (31, 21, -1, 0, 1))},
    40: {"shut": ((23, 0, 0, 1, 3), (24, 0, 0, 1, 3), (0, 23, 1, 0, 3), (0, 24, 1, 0, 3), (45, 23, 1, 0, 3), (45, 24, 1, 0, 3), (23, 45, 0, 1, 3), (24, 45, 0, 1, 3),
                  (7, 7, 1, 1, 3), (40, 7, -1, 1, 3), (40, 40, -1, -1, 3)),
         "open": ((22, 0, 0, 1, 3), (23, 0, 0, 1, 3), (24, 0, 0, 1, 3), (25, 0, 0, 1, 3), (0, 22, 1, 0, 3), (0, 23, 1, 0, 3), (0, 24, 1, 0, 3), (0, 25, 1, 0, 3),
                  (45, 22, 1, 0, 3), (45, 23, 1, 0, 3), (45, 24, 1, 0, 3), (45, 25, 1, 0, 3), (22, 45, 0, 1, 3), (23, 45, 0, 1, 3), (24, 45, 0, 1, 3), (25, 45, 0, 1, 3),
                  (4, 4, 1, 1, 5), (43, 4, -1, 1, 5), (43, 43, -1, -1, 5), (14, 1, 1, 1, 2), (33, 1, -1, 1, 2), (1, 14, 1, 1, 2), (46, 14, -1, 1, 2), (46, 33, -1, -1, 2), (33, 46, -1, -1, 2))},
}


def rgba(h):
    return (int(h[:2], 16), int(h[2:4], 16), int(h[4:], 16), 255)


def silhouettes():
    """{size: (disc, f)}: two sets of (x, y); the f is the air the disc encloses"""
    out, name, rows = {}, None, []
    for line in MAPS.read_text(encoding="utf-8").splitlines() + ["@"]:
        if line.startswith("@"):
            if name:
                out[name] = parse(rows, name)
            name, rows = int(line[1:]) if line[1:] else None, []
        elif line and name:                    # (a row may begin with its #: the comments stand above the first @)
            rows.append(line)
    return out


def parse(rows, size):
    if len(rows) != size or {len(r) for r in rows} != {size}:
        raise SystemExit(f"art/fedora-head.txt @{size}: not {size} × {size}")
    disc = {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "#"}
    seen, todo = set(), [(x, y) for x in range(-1, size + 1) for y in (-1, size)] + [(x, y) for y in range(size) for x in (-1, size)]
    while todo:
        p = todo.pop()
        if p in seen or p in disc or not (-1 <= p[0] <= size and -1 <= p[1] <= size):
            continue
        seen.add(p)
        todo += [(p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)]
    f = {(x, y) for y in range(size) for x in range(size) if (x, y) not in disc and (x, y) not in seen}
    return disc, f


def blood(size, disc, state):
    """the runs below the disc, each from the disc's own lower edge: (x, y) of a run, of its bead, of the drop"""
    run, bead, drops = set(), set(), set()
    for col, far in DRIPS[size][state]:
        bottom = max(y for x, y in disc if x == col)
        for w in range(2 if size >= 26 else 1):
            for y in range(bottom + 1, bottom + 1 + far):
                run.add((col + w, y))
        if size == 40:
            tip = bottom + far + 1         # (a pendant: the run swells to four, closes to two)
            bead |= {(col - 1, tip - 1), (col + 2, tip - 1), (col - 1, tip), (col, tip), (col + 1, tip), (col + 2, tip), (col, tip + 1), (col + 1, tip + 1)}
    if state == "open" and DRIPS[size]["drop"]:
        col, gap = DRIPS[size]["drop"]
        bottom = max(y for x, y in disc if x == col)
        drops |= {(col, bottom + gap), (col, bottom + gap + 1), (col + 1, bottom + gap + 1), (col, bottom + gap + 2), (col + 1, bottom + gap + 2)}
    return run, bead, drops


def rim(size, disc, f, side):
    """the disc's pixels within a band of its outer edge (the f is no edge), along a diagonal: (−1, −1) the light, (1, 1) the shade"""
    band = {16: 1, 26: 2}.get(size, 3)
    dx, dy = side
    whole = disc | f
    return {(x, y) for x, y in disc if any((x + dx * k, y + dy * k) not in whole for k in range(1, band + 1))}


def drawn(mood, size, state, w, h, ox, oy):
    """the head on a w × h canvas: the disc's map from (ox, oy)"""
    disc, f = silhouettes()[size]
    ink = BLOODY if mood == "dark" else LIGHTY
    im = Image.new("RGBA", (w, h), AIR)
    px = im.load()
    def put(p, c):
        px[p[0] + ox, p[1] + oy] = rgba(c)
    if mood == "dark":
        shade, lit = rim(size, disc, f, (1, 1)), rim(size, disc, f, (-1, -1))
        for p in disc:
            put(p, ink["shade"] if p in shade else ink["lit"] if p in lit else ink["disc"])
        for p in GLOSS[size]:
            put(p, ink["shine"])
        run, bead, drops = blood(size, disc, state)
        for p in run | bead:
            put(p, ink["disc"])
        for x, y in run:
            if size >= 26 and (x + 1, y) not in run:
                put((x, y), ink["shade"])
        for p in drops:
            put(p, ink["disc"])
        for p in f:
            put(p, ink["f"])
        if size >= 26:                     # (the f's shadow side)
            for x, y in f:
                if (x + 1, y + 1) in disc:
                    put((x, y), ink["f_shade"])
    else:
        edge = {(x, y) for x, y in disc if {(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)} - disc - f}
        shade, lit = rim(size, disc, f, (1, 1)), rim(size, disc, f, (-1, -1))
        for p in disc:
            put(p, ink["edge"] if p in edge else ink["shade"] if p in shade else ink["lit"] if p in lit else ink["disc"])
        for p in GLOSS[size]:
            put(p, ink["shine"])
        for p in f:
            put(p, ink["f"])
        for x, y, dx, dy, n in RAYS[size][state]:
            for k in range(n):
                px[x + dx * k, y + dy * k] = rgba(ink["ray_lit"] if k == 0 and n > 1 else ink["ray"])
    return im


def picture(mood, size, state, w, h):
    ox = (w - size) // 2
    if mood == "dark":
        return drawn(mood, size, state, w, h, ox, 1)
    return drawn(mood, size, state, w, h, ox, (h - size) // 2)


def glyph(mood, state):
    """the prompt's head, one ink: 24 × 20, the disc 16 across on its columns 4–19"""
    return [
        "".join("#" if px[3] and px[:3] != rgba(BLOODY["f"] if mood == "dark" else LIGHTY["f"])[:3] else "." for px in (im.getpixel((x, y)) for x in range(24)))
        for im in [picture(mood, 16, state, 24, 20)] for y in range(20)
    ]


GLYPHS = {"head-bloody": ("dark", "shut"), "head-bloody-run": ("dark", "open"), "head-lighty": ("light", "shut"), "head-lighty-open": ("light", "open")}


def write_glyphs():
    """into art/icons.txt, as its two glyphs each, 16 and 8 wide"""
    text = ICONS.read_text(encoding="utf-8")
    for icon, (mood, state) in GLYPHS.items():
        rows = glyph(mood, state)
        for suffix, cut in (("", (0, 16)), ("-2", (16, 24))):
            block = f"@{icon}{suffix}\n" + "\n".join(r[cut[0]:cut[1]] for r in rows) + "\n"
            text, n = re.subn(rf"^@{re.escape(icon)}{re.escape(suffix)}\n(?:[.#]+\n)+", lambda _, b=block: b, text, flags=re.M)
            if n != 1:
                raise SystemExit(f"art/icons.txt: @{icon}{suffix} found {n} times")
    ICONS.write_text(text, encoding="utf-8")


def sixel(im):
    """RGBA → a sixel: the transparent stays the terminal's (P2 = 1), one register an ink, whole"""
    w, h = im.size
    px = im.load()
    inks = sorted({px[x, y][:3] for y in range(h) for x in range(w) if px[x, y][3]})
    out = ['\x1bP0;1;0q"1;1;%d;%d' % (w, h)]
    out += ["#%d;2;%d;%d;%d" % (i, *(round(v * 100 / 255) for v in c)) for i, c in enumerate(inks)]
    for y0 in range(0, h, 6):
        for i, c in enumerate(inks):
            cols = [sum(1 << k for k in range(min(6, h - y0)) if px[x, y0 + k][3] and px[x, y0 + k][:3] == c) for x in range(w)]
            if not any(cols):
                continue
            line, x, end = ["#%d" % i], 0, max(k for k in range(w) if cols[k]) + 1
            while x < end:
                n = 1
                while x + n < end and cols[x + n] == cols[x]:
                    n += 1
                ch = chr(63 + cols[x])
                line.append("!%d%s" % (n, ch) if n > 3 else ch * n)
                x += n
            out.append("".join(line) + "$")
        out.append("-")
    return "".join(out) + "\x1b\\"


def fetch_picture(mood):
    im = Image.new("RGBA", (288, 300), AIR)
    im.paste(picture(mood, 40, "shut", 48, 48).resize((288, 288), Image.NEAREST), (0, 6))
    return im


def write_all():
    for mood in ("dark", "light"):
        d = THEMES / mood
        for suffix, state in (("", "shut"), ("-open", "open")):
            picture(mood, 26, state, 32, 30).save(d / f"head-32{suffix}.png", optimize=True)
            picture(mood, 40, state, 48, 48).save(d / f"head-48{suffix}.png", optimize=True)
        (SHARE / mood / "head.six").write_text(sixel(fetch_picture(mood)), encoding="ascii")
    write_glyphs()


def sheet(d):
    """every size and state on its own ground, 1× above, 6× below"""
    d.mkdir(parents=True, exist_ok=True)
    grounds = {"dark": ("181715", "26211b"), "light": ("e8e3c2", "f9f5df")}
    for mood, (term, tile) in grounds.items():
        ims = [(picture(mood, 26, s, 32, 30), tile) for s in ("shut", "open")] + [(picture(mood, 40, s, 48, 48), tile) for s in ("shut", "open")]
        glyphs = []
        for s in ("shut", "open"):
            g = Image.new("RGBA", (24, 20), AIR)
            ink = BLOODY["lit"] if mood == "dark" else LIGHTY["edge"]
            for y, r in enumerate(glyph(mood, s)):
                for x, c in enumerate(r):
                    if c == "#":
                        g.putpixel((x, y), rgba(ink))
            glyphs.append((g, term))
        ims = glyphs + ims
        out = Image.new("RGB", (sum(i.width * 6 + 16 for i, _ in ims) + 16, 340), rgba(term)[:3])
        x = 16
        for im, ground in ims:
            one = Image.new("RGB", im.size, rgba(ground)[:3])
            one.paste(im, (0, 0), im)
            out.paste(one, (x, 8))
            out.paste(one.resize((im.width * 6, im.height * 6), Image.NEAREST), (x, 60))
            x += im.width * 6 + 16
        out.save(d / f"head-{mood}.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--sheet", type=pathlib.Path)
    a = ap.parse_args()
    if a.sheet:
        sheet(a.sheet)
    else:
        write_all()


if __name__ == "__main__":
    main()
