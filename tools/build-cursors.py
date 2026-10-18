#!/usr/bin/env python3
"""tools/build-cursors.py — build the desktop's mouse pointers, "Sumi", from art/cursors.txt.

    python3 tools/build-cursors.py                    # writes both pointer themes
    python3 tools/build-cursors.py --preview out.png  # also draws them all (Pillow): the handbook's figure
    python3 tools/build-cursors.py --preview out.png --marks   # … each square and hotspot marked, to check

Output (committed, so a normal install needs neither Python nor Pillow):
    configs/system/usr/share/icons/Sumi-dark/     pale paper ink with a sumi rim: the dark theme
    configs/system/usr/share/icons/Sumi-light/    sumi-black ink with a paper rim: the light theme
                                                  (for every account and the login screen too)
        index.theme
        cursors/<name>         an Xcursor file for every shape drawn in art/cursors.txt
    art/cursor-names.txt         "OTHER-NAME SHAPE" for every other name programs ask by
                               (left_ptr, hand2, xterm, the hashes Qt and old toolkits use…):
                               theme.sh makes each a link beside its shape, in both themes
                               (the toolkit itself holds only plain files)
kawa-theme points ~/.local/share/icons/default at the variant of the theme in use; the login
screen (cage) wears the one of the theme you last had (XCURSOR_THEME, setup.sh). Every name
a program may ask for is drawn or linked here, so index.theme inherits nothing: no shape ever
falls through to another theme's (tests/static/test_pointers.sh holds the list).

Every shape is drawn twice, pixel by pixel: once on a 24 px grid and once on a 32 px grid.
Each file holds three sizes, none of them resampled, so no edge is ever smoothed:
    24   the 24 px drawing, 1:1 — the desktop's own pixel scale, like its fonts and icons
    32   the 32 px drawing, 1:1 — for screens scaled 1.25 to 1.5, and XCURSOR_SIZE=32
    48   the 24 px drawing with every pixel doubled — for 2× screens
Each image is a square of its size (the drawing at its top left), so a hotspot is where the
drawing says and every image divides evenly by any whole screen scale.

The colours are the palettes' (tools/build-themes.py, imported), so a colour changed there
changes here at the next run. Standard library only; --preview also needs Pillow.
"""
import argparse
import importlib.util
import pathlib
import re
import shutil
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "art" / "cursors.txt"
ICONS = ROOT / "configs/system/usr/share/icons"
NAMES = ROOT / "art" / "cursor-names.txt"

sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
spec = importlib.util.spec_from_file_location("themes", ROOT / "tools/build-themes.py")
themes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themes)
P = themes.P

# what each character of a drawing is, in each variant: a palette colour of that theme
#   #  ink   the pointer's body           o  rim   the outline that parts it from what is under
#   :  wash  thinned ink: the dry brush, the ensō's ghost
#   R  vermilion: "not here" alone (the seals)
# Each variant is the other's negative: its ink is the strongest ink of its own theme, its rim
# the opposite, so a pointer reads on its own theme's windows and on the other one's too.
VARIANTS = {
    "dark":  {"#": P["dark"]["strong"], "o": P["dark"]["ground"], ":": P["dark"]["muted"],
              "R": P["dark"]["accent"]},
    "light": {"#": P["light"]["strong"], "o": P["light"]["hi"], ":": P["light"]["muted"],
              "R": P["light"]["accent"]},
}
ABOUT = {"dark": "pale ink with a sumi rim, for the dark theme",
         "light": "sumi ink with a paper rim, for the light theme"}
GRIDS = (24, 32)                       # the two drawings of every shape
SIZES = ((24, 24, 1), (32, 32, 1), (48, 24, 2))   # (nominal size, drawing, pixel scale)
STATIC = "#o:R"                        # a still drawing's colours
STEPS = "123456789abcdefghijklmnopqrstuvwxyz"     # an animated drawing's order of strokes
# the animation, in milliseconds: the stroke drawn in ink over the last one's ghost in wash
# (DRAW for all of it, whatever its number of steps), then the ensō held complete — so the
# pointer is never empty, and always the same size
DRAW, HOLD = 760, 520


def fail(line, msg):
    sys.exit(f"cursors.txt:{line}: {msg}")


def parse(text):
    """The drawings ({(name, grid): drawing}), in file order, and the other names."""
    drawings, names, cur = {}, {}, None
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if cur is None and (line == "#" or line.startswith("# ")):
            continue                                         # a comment between drawings
        if line.startswith("@"):
            name, grid, *opts = line[1:].split() + [""] * max(0, 2 - len(line[1:].split()))
            if not re.fullmatch(r"[a-z][a-z0-9_-]*", name):
                fail(n, f"bad pointer name {name!r}")
            if grid not in ("24", "32"):
                fail(n, f"{name}: the grid is 24 or 32, not {grid!r}")
            cur = {"name": name, "grid": int(grid), "line": n, "rows": [], "halo": False,
                   "anim": False, "hot": None, "at": (0, 0), "over": None, "turn": None, "mirror": None}
            for o in filter(None, opts):
                k, _, v = o.partition("=")
                if o in ("halo", "anim"):
                    cur[o] = True
                elif k in ("hot", "at") and re.fullmatch(r"\d+,\d+", v):
                    cur[k] = tuple(int(x) for x in v.split(","))
                elif k in ("over", "turn", "mirror") and v:
                    cur[k] = v
                else:
                    fail(n, f"{name}: bad setting {o!r}")
            if (name, cur["grid"]) in drawings:
                fail(n, f"{name} is drawn twice on the {grid} grid")
            drawings[(name, cur["grid"])] = cur
        elif line.startswith("= "):
            what, *others = line[2:].split()
            if not others:
                fail(n, f"{what}: no other names")
            for o in others:
                if o in names:
                    fail(n, f"{o} is named twice")
                names[o] = (what, n)
        elif line and cur is not None and re.fullmatch(r"[^ ]+", line):
            cur["rows"].append((n, line))
        elif not line:
            cur = None
        else:
            fail(n, f"unexpected {line!r}")
    return drawings, names


def cells(d):
    """A drawing as rows of cells: None (clear), ("c", colour, halo) or ("s", step, halo)."""
    rows, chars = [], STEPS if d["anim"] else STATIC
    for n, r in d["rows"]:
        bad = set(r) - set(chars) - {"."}
        if bad:
            fail(n, f"{d['name']}: {''.join(sorted(bad))!r} is not one of {chars!r}")
        rows.append([None if ch == "." else ("s", STEPS.index(ch) + 1, True) if d["anim"] and ch in STEPS
                     else ("c", ch, d["halo"]) for ch in r])
    if len({len(r) for r in rows}) > 1:
        fail(d["line"], f"{d['name']}: rows differ in width")
    return rows


def resolve(drawings):
    """Every drawing as cells with its hotspot: the ones made from another (over, turn,
    mirror) are made here, from that one on the same grid."""
    done = {}

    def get(key, chain=()):
        if key in done:
            return done[key]
        if key not in drawings:
            sys.exit(f"cursors.txt: {key[0]} is not drawn on the {key[1]} grid")
        d = drawings[key]
        if key in chain:
            fail(d["line"], f"{d['name']} is made from itself")
        made = [k for k in ("over", "turn", "mirror") if d[k]]
        if len(made) > 1:
            fail(d["line"], f"{d['name']}: one of over=, turn=, mirror=")
        if made and made[0] != "over":
            if d["rows"] or d["hot"]:
                fail(d["line"], f"{d['name']}: {made[0]}= takes its drawing and hotspot from {d[made[0]]}")
            src, (hx, hy) = get((d[made[0]], key[1]), chain + (key,))
            h, w = len(src), len(src[0])
            if made[0] == "turn":                            # a quarter turn, clockwise
                rows = [[src[h - 1 - x][y] for x in range(h)] for y in range(w)]
                hot = (h - 1 - hy, hx)
            else:                                            # left for right
                rows = [r[::-1] for r in src]
                hot = (w - 1 - hx, hy)
        else:
            if not d["rows"]:
                fail(d["line"], f"{d['name']} has no drawing")
            rows = cells(d)
            hot = d["hot"]
            if d["over"]:                    # laid over another drawing, its top left at at=X,Y
                base, bhot = get((d["over"], key[1]), chain + (key,))
                ax, ay = d["at"]
                h, w = max(len(base), ay + len(rows)), max(len(base[0]), ax + len(rows[0]))
                grid = [[None] * w for _ in range(h)]
                for (ox, oy), layer in (((0, 0), base), ((ax, ay), rows)):
                    for y, r in enumerate(layer):
                        for x, c in enumerate(r):
                            if c is not None:
                                grid[oy + y][ox + x] = c
                rows, hot = grid, hot or bhot
            elif d["at"] != (0, 0):
                fail(d["line"], f"{d['name']}: at= places a drawing laid over another (over=)")
            if hot is None:
                fail(d["line"], f"{d['name']}: no hot=X,Y")
        w, h = len(rows[0]), len(rows)
        if not (0 <= hot[0] < w and 0 <= hot[1] < h):
            fail(d["line"], f"{d['name']}: the hotspot {hot} is outside the drawing")
        if w > key[1] or h > key[1]:
            fail(d["line"], f"{d['name']}: {w}×{h} does not fit the {key[1]} grid")
        if any(c and c[2] and (x in (0, w - 1) or y in (0, h - 1))
               for y, r in enumerate(rows) for x, c in enumerate(r)):
            fail(d["line"], f"{d['name']}: no room for the rim (leave a clear edge round a halo or anim drawing)")
        done[key] = (rows, hot)
        return done[key]

    return {key: get(key) for key in drawings}


def frames(rows):
    """The pictures of a drawing — one for a still, the strokes in order for an animated
    one — each a grid of colour characters, with delays (ms): [(grid, delay)]."""
    steps = sorted({c[1] for r in rows for c in r if c and c[0] == "s"})

    def picture(show):                                       # show(step) → colour or None
        h, w = len(rows), len(rows[0])
        g = [[None] * w for _ in range(h)]
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c:
                    g[y][x] = c[1] if c[0] == "c" else show(c[1])
        inked = [[c is not None and c[2] and g[y][x] is not None for x, c in enumerate(r)]
                 for y, r in enumerate(rows)]                # (what is shown, before any rim)
        for y in range(h):                                   # the rim round the haloed ink
            for x in range(w):
                if inked[y][x]:
                    for yy in range(max(0, y - 1), min(h, y + 2)):
                        for xx in range(max(0, x - 1), min(w, x + 2)):
                            if g[yy][xx] is None:
                                g[yy][xx] = "o"
        return g

    if not steps:
        return [(picture(None), 0)]
    out = [(picture(lambda s, k=k: "#" if s <= k else ":"), DRAW // len(steps)) for k in steps[:-1]]
    out.append((picture(lambda s: "#"), HOLD))                 # (its last step: complete)
    return out


def argb(hexrgb):
    return 0xFF000000 | int(hexrgb, 16)


def image(grid, colours, size, scale):
    """One frame as Xcursor pixels: little-endian ARGB, a size × size square."""
    px = bytearray(size * size * 4)
    for y, r in enumerate(grid):
        for x, ch in enumerate(r):
            if ch is None:
                continue
            v = struct.pack("<I", argb(colours[ch]))
            for dy in range(scale):
                row = ((y * scale + dy) * size + x * scale) * 4
                px[row:row + 4 * scale] = v * scale
    return bytes(px)


def xcursor(made, name, colours):
    """One Xcursor file: a table of contents, then one image chunk per size and frame."""
    chunks = []
    for size, grid, scale in SIZES:
        rows, (hx, hy) = made[(name, grid)]
        for pic, delay in frames(rows):
            chunks.append((size, struct.pack("<9I", 36, 0xFFFD0002, size, 1, size, size,
                                             hx * scale, hy * scale, delay)
                           + image(pic, colours, size, scale)))
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(chunks))
    pos = len(head) + 12 * len(chunks)
    toc, body = b"", b""
    for size, chunk in chunks:
        toc += struct.pack("<III", 0xFFFD0002, size, pos + len(body))
        body += chunk
    return head + toc + body


def preview(made, shapes, path, marks):
    """The contact sheet: every shape in both variants, each on both theme grounds — 4× (the
    24 px drawing) above the three sizes at 1:1; then each animated one frame by frame (2×),
    as it plays. With marks, the 24 px square's edge and ticks and a dot at the hotspot, to
    check the alignment by: on the sheet alone (never in a pointer, nor the handbook)."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        sys.exit("--preview needs python3-pillow")
    font = None
    for f in ("/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if pathlib.Path(f).exists():
            font = ImageFont.truetype(f, 12)
            break

    def rgb(h):
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

    def held(rows):                                          # a still, or the ensō complete
        fr = frames(rows)
        return fr[-1][0]

    def paint(d, grid, x0, y0, z, colours):
        for y, r in enumerate(grid):
            for x, c in enumerate(r):
                if c:
                    d.rectangle([x0 + x * z, y0 + y * z, x0 + x * z + z - 1, y0 + y * z + z - 1], fill=colours[c])

    Z, pad, cols = 4, 12, 8
    cw, ch = 24 * Z + 3 * pad, 24 * Z + 2 * pad + 48 + 16
    anim = [n for n in shapes if len(frames(made[(n, 24)][0])) > 1]
    longest = max([len(frames(made[(n, 24)][0])) for n in anim] or [0])
    nrows = -(-len(shapes) // cols)
    band = 20 + nrows * ch + len(anim) * (48 + pad) + pad
    W = max(cols * cw + pad, longest * 52 + 2 * pad)
    sheet = Image.new("RGB", (W, 4 * band), (0, 0, 0))
    d = ImageDraw.Draw(sheet)
    for b, (v, g) in enumerate((v, g) for v in VARIANTS for g in ("dark", "light")):
        colours = {k: rgb(c) for k, c in VARIANTS[v].items()}
        fg, edge, mark = rgb(P[g]["text"]), rgb(P[g]["edge"]), (40, 190, 220)
        top = b * band
        d.rectangle([0, top, W, top + band - 1], fill=rgb(P[g]["ground"]))
        d.text((pad, top + 4), f"Sumi-{v} on the {g} theme's ground", fill=fg, font=font)
        for i, n in enumerate(shapes):
            x0, y0 = pad + 4 + (i % cols) * cw, top + 24 + (i // cols) * ch
            rows, (hx, hy) = made[(n, 24)]
            if marks:
                d.rectangle([x0 - 1, y0 - 1, x0 + 24 * Z, y0 + 24 * Z], outline=edge)
            paint(d, held(rows), x0, y0, Z, colours)
            if marks:
                cx, cy = x0 + hx * Z + Z // 2, y0 + hy * Z + Z // 2      # the hotspot
                d.line([cx - 1, y0 - 6, cx, y0 - 3], fill=mark, width=2)
                d.line([x0 - 6, cy - 1, x0 - 3, cy], fill=mark, width=2)
                d.rectangle([cx - 1, cy - 1, cx, cy], fill=mark)
            sx = x0
            for size, grid, scale in SIZES:                         # the real thing, 1:1
                paint(d, held(made[(n, grid)][0]), sx, y0 + 24 * Z + pad, scale, colours)
                sx += size + 6
            d.text((x0, y0 + 24 * Z + pad + 50), n, fill=fg, font=font)
        y0 = top + 24 + nrows * ch
        for n in anim:                                              # as it plays, 2×
            for k, (pic, _) in enumerate(frames(made[(n, 24)][0])):
                paint(d, pic, pad + 4 + k * 52, y0, 2, colours)
            y0 += 48 + pad
    sheet.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--preview", metavar="PNG")
    ap.add_argument("--marks", action="store_true", help="--preview: mark each square and hotspot")
    a = ap.parse_args()
    drawings, names = parse(SRC.read_text())
    made = resolve(drawings)
    shapes = list(dict.fromkeys(n for n, _ in drawings))
    for n in shapes:
        for g in GRIDS:
            if (n, g) not in made:
                sys.exit(f"cursors.txt: {n} has no drawing on the {g} grid")
    for o, (what, line) in names.items():
        if what not in shapes:
            fail(line, f"{what} is not drawn")
        if o in shapes:
            fail(line, f"{o} is drawn, so it cannot also be another name of {what}")
    for v, colours in VARIANTS.items():
        out = ICONS / f"Sumi-{v}"
        if (out / "cursors").exists():
            shutil.rmtree(out / "cursors")                   # (a name taken out goes with it)
        (out / "cursors").mkdir(parents=True)
        for n in shapes:
            (out / "cursors" / n).write_bytes(xcursor(made, n, colours))
        (out / "index.theme").write_text(
            "[Icon Theme]\n"
            f"Name=Sumi-{v}\n"
            f"Comment=Sumi pointers: {ABOUT[v]} (tools/build-cursors.py)\n")
    NAMES.write_text(
        "# art/cursor-names.txt — written by tools/build-cursors.py from art/cursors.txt: every other\n"
        "# name a program may ask for, and the pointer it gets. theme.sh makes each a link beside that\n"
        "# pointer, in Sumi-dark and Sumi-light (/usr/share/icons/Sumi-*/cursors/).\n"
        + "".join(f"{o} {what}\n" for o, (what, _) in sorted(names.items())))
    print(f"{len(shapes)} pointers, {len(names)} other names → "
          f"{ICONS.relative_to(ROOT)}/Sumi-{{dark,light}}/cursors/")
    if a.preview:
        preview(made, shapes, a.preview, a.marks)


if __name__ == "__main__":
    main()
