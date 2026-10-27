#!/usr/bin/env python3
"""tools/regress/shots.py — what a kit shot shows, for the regression checks (tools/regress/*.sh):

  shots.py popups SHOT…        each shot: its name, how many popups it shows, and their boxes —
                               what is not the kit's flat ground under the bar, pooled 4×4 and
                               dilated (a window's own parts one), its big pieces, those inside
                               another merged
  shots.py keys SHOT [X,Y,W,H] the keys a menu shows (its 1 px framed boxes one row high, two or
                               more side by side): "X Y W H" each, left to right, in the region
  shots.py centre SHOT X Y     the colour there: rrggbb
  shots.py differ A B X,Y,W,H  whether the two shots differ in that region (exit 0) or not (1)
  shots.py middle SHOT Y       the bar's middle group (the date's): its ink's left and right
                               edge on row Y, and its centre ×2 (whole numbers: 1920 = 960)
  shots.py edges SHOT Y X0 X1  the first and the last pixel on row Y, between X0 and X1, that is
                               not the ground (a frame's two hairlines), and their centre ×2
  shots.py bar SHOT FIBRE      the bar measured (docs/design-system.md §8): a line per tile — its
                               box (hairline to shadow column), the paper, the ink's first and
                               last column and row, the paper to the ink either side — then the
                               rows of the first tile, the gaps between the tiles, and the
                               clock's parts (the scroll's rods to the ink, the ink gaps, the
                               kanji's centre); FIBRE: the theme's kami-fibre.png (its colours are
                               paper, not ink)
  shots.py frames SHOT ROW     two tiled windows' frames (design-system §4, §12) across ROW: each
                               hairline's x and colour, the shadow's column after the right one,
                               the gaps — then the right window's bottom-right corner, 7 × 4
                               pixels as letters (its hairline, the corner left out, the shadow)
Exit 0 · 1 a check's own "no" (differ) · 2 misuse or an unreadable shot.
"""
import sys

import numpy as np
from PIL import Image

GROUND = np.array([0x18, 0x17, 0x15])          # the kit's flat ground (tools/kit.sh)


def load(f):
    try:
        return np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)
    except OSError as e:
        sys.exit(f"shots: {f}: {e}")


def popups(f, top=40):
    a = load(f)[top:]
    m = np.abs(a - GROUND).max(axis=2) > 8
    h, w = m.shape[0] // 4, m.shape[1] // 4
    s = m[:h * 4, :w * 4].reshape(h, 4, w, 4).any(axis=(1, 3))
    d = s.copy()
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            d |= np.roll(np.roll(s, dy, 0), dx, 1)
    seen = np.zeros_like(d)
    boxes = []
    for y in range(h):
        for x in range(w):
            if d[y, x] and not seen[y, x]:
                st, ys, xs = [(y, x)], [y, y], [x, x]
                seen[y, x] = True
                while st:
                    cy, cx = st.pop()
                    ys = [min(ys[0], cy), max(ys[1], cy)]
                    xs = [min(xs[0], cx), max(xs[1], cx)]
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < h and 0 <= nx < w and d[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            st.append((ny, nx))
                b = (xs[0] * 4, ys[0] * 4 + top, (xs[1] + 1) * 4, (ys[1] + 1) * 4 + top)
                if b[2] - b[0] >= 150 and b[3] - b[1] >= 100:
                    boxes.append(b)
    return [b for b in boxes if not any(o != b and o[0] <= b[0] and o[1] <= b[1] and o[2] >= b[2] and o[3] >= b[3]
                                        for o in boxes)]


def keys(f, region=None):
    """Framed boxes one row high (20 px), 40 px wide or more: a run of one colour (not the
    ground) on a row, the same run 19 rows below, both ends' columns that colour between."""
    a = load(f)
    x0, y0, w, h = region or (0, 0, a.shape[1], a.shape[0])
    sub = a[y0:y0 + h, x0:x0 + w]
    found = []
    for y in range(sub.shape[0] - 19):
        top, bot = sub[y], sub[y + 19]
        x = 0
        while x < sub.shape[1]:
            c = top[x]
            run = 1
            while x + run < sub.shape[1] and (top[x + run] == c).all():
                run += 1
            if (run >= 40 and np.abs(c - GROUND).max() > 8 and (bot[x:x + run] == c).all()
                    and (sub[y:y + 20, x] == c).all() and (sub[y:y + 20, x + run - 1] == c).all()):
                found.append((x0 + x, y0 + y, run, 20))
            x += run
    return sorted(set(found), key=lambda k: (k[1], k[0]))


def bar(f, fibre):
    """The bar's tiles, rows, gaps and clock as numbers (see the module's doc)."""
    im = load(f)
    fib = {tuple(int(v) for v in c) for c in np.asarray(Image.open(fibre).convert("RGB")).reshape(-1, 3)}
    row = im[13]
    out, tiles, x = [], [], 0
    while x < im.shape[1]:
        if (row[x] != GROUND).any():
            x0 = x
            while x < im.shape[1] and (row[x] != GROUND).any():
                x += 1
            tiles.append((x0, x - 1))
        else:
            x += 1
    paper_of = lambda a, b, ink_set: [(c, y) for c in range(a, b + 1) for y in range(5, 23)
                                      if tuple(int(v) for v in im[y, c]) not in ink_set]
    for a, b in tiles:
        scroll = (b - a) > 150                       # (the clock: rods 4 px, no shadow column)
        L, R = (a + 3, b - 3) if scroll else (a, b - 1)   # (the scroll: the rods, 4 px, are its edges)
        paper = fib | {tuple(int(v) for v in im[13, L + 1])}
        ink = paper_of(L + 1, R - 1, paper)
        if not ink:
            out.append(f"tile {a} {b} paper {L + 1} {R - 1} ink none")
            continue
        xs = [p[0] for p in ink]
        ys = [p[1] for p in ink]
        out.append(f"tile {a} {b} paper {L + 1} {R - 1} ink {min(xs)} {max(xs)} rows {min(ys)} {max(ys)} "
                   f"left {min(xs) - (L + 1)} right {(R - 1) - max(xs)}" + (" scroll" if scroll else ""))
        if scroll:
            cols = sorted({p[0] for p in ink})
            parts = []
            for c in cols:
                if parts and c - parts[-1][1] <= 5:
                    parts[-1][1] = c
                else:
                    parts.append([c, c])
            out.append("clock " + " ".join(f"{p0}-{p1}" for p0, p1 in parts)
                       + " gaps " + " ".join(str(q[0] - p[1] - 1) for p, q in zip(parts, parts[1:])))
    col = im[:, tiles[0][0] + 1]
    runs, y = [], 0
    while y < 27:
        y0 = y
        while y < 27 and (col[y] == col[y0]).all():
            y += 1
        runs.append(f"{y0}+{y - y0}")
    out.append("rows " + " ".join(runs))
    out.append("gaps " + " ".join(str(t2[0] - t1[1] - 1) for t1, t2 in zip(tiles, tiles[1:])))
    return out


def frames(f, y):
    """The frames across row y, and the right window's bottom-right corner (see the doc)."""
    im = load(f)
    row = im[y]
    xs = [x for x in range(1, im.shape[1]) if (row[x] != row[x - 1]).any()]
    out = ["changes " + " ".join(f"{x}:{row[x][0]:02x}{row[x][1]:02x}{row[x][2]:02x}" for x in xs)]
    # the right window's right hairline: the last change before the screen's edge but two
    r = [x for x in xs if x < im.shape[1] - 4]
    if r:
        hx = r[-3] if len(r) >= 3 else r[-1]
        hair = im[y, hx]                              # (the hairline's own colour, down to the row
        bottom = y                                    #  before its corner: then the bottom hairline's row)
        while bottom + 1 < im.shape[0] and (im[bottom + 1, hx] == hair).all():
            bottom += 1
        bottom += 1
        names = {}
        out.append(f"corner at {hx},{bottom}")
        for yy in range(bottom - 1, bottom + 3):
            out.append("".join(names.setdefault(tuple(int(v) for v in im[yy, xx]), chr(97 + len(names)))
                               for xx in range(hx - 4, hx + 3)))
    return out


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "popups":
        for f in argv[2:]:
            b = popups(f)
            print(f.rsplit("/", 1)[-1][:-4], len(b), " ".join(f"{x},{y},{x2 - x},{y2 - y}" for x, y, x2, y2 in b))
    elif cmd == "keys":
        reg = tuple(int(v) for v in argv[3].split(",")) if len(argv) > 3 else None
        for k in keys(argv[2], reg):
            print(*k)
    elif cmd == "centre":
        a = load(argv[2])
        r, g, b = a[int(argv[4]), int(argv[3])]
        print(f"{r:02x}{g:02x}{b:02x}")
    elif cmd == "differ":
        x, y, w, h = (int(v) for v in argv[4].split(","))
        a, b = load(argv[2])[y:y + h, x:x + w], load(argv[3])[y:y + h, x:x + w]
        return 0 if (a != b).any() else 1
    elif cmd == "middle":
        row = load(argv[2])[int(argv[3])]
        ink = np.nonzero(np.abs(row - GROUND).max(axis=1) > 8)[0]
        mid = [i for i in ink if 640 <= i < 1280]          # (the middle third: the date's group)
        if not mid:
            sys.exit("shots: no middle group on that row")
        print(mid[0], mid[-1], mid[0] + mid[-1] + 1)
    elif cmd == "edges":
        row = load(argv[2])[int(argv[3])]
        x0, x1 = int(argv[4]), int(argv[5])
        ink = [i for i in np.nonzero(np.abs(row - GROUND).max(axis=1) > 8)[0] if x0 <= i < x1]
        if not ink:
            sys.exit("shots: nothing on that row")
        print(ink[0], ink[-1], ink[0] + ink[-1] + 1)
    elif cmd == "frames":
        print("\n".join(frames(argv[2], int(argv[3]))))
    elif cmd == "bar":
        print("\n".join(bar(argv[2], argv[3])))
    else:
        sys.exit(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
