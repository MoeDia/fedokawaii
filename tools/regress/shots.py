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
  shots.py tv ICONS DIR…       the television frame by frame: each DIR's f-NANOSECONDS.png, the bar's
                               right in time order, held to ICONS' (art/icons.txt) tv-0…tv-3 —
                               four pictures and no other, exactly the art's pixels moving, in
                               order, six a second. Exit 1 with what broke.
Exit 0 · 1 a check's own "no" (differ, tv) · 2 misuse or an unreadable shot.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image

GROUND = np.array([0x18, 0x17, 0x15])          # the kit's flat ground — the theme's own (tools/kit.sh):
                                               # read from each shot as it is loaded (load)


def load(f):
    global GROUND
    try:
        a = np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)
    except OSError as e:
        sys.exit(f"shots: {f}: {e}")
    GROUND = a[1, 2].copy()        # (row 1, column 2: above the bar's tiles and left of its first)
    return a


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
    # (a tile's columns: its top hairline or its middle row, never the ground — art may hold the
    # ground's colour on the middle row, the demon's mouth; the hairline leaves out its corners)
    in_tile = (im[13] != GROUND).any(axis=1) | (im[3] != GROUND).any(axis=1)
    out, tiles, x = [], [], 0
    while x < im.shape[1]:
        if in_tile[x]:
            x0 = x
            while x < im.shape[1] and in_tile[x]:
                x += 1
            tiles.append((x0, x - 1))
        else:
            x += 1
    def paper_of(a, b, ink_set):
        return [(c, y) for c in range(a, b + 1) for y in range(5, 23)
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
                       + " gaps " + " ".join(str(q[0] - p[1] - 1) for p, q in zip(parts, parts[1:], strict=False)))
    col = im[:, tiles[0][0] + 1]
    runs, y = [], 0
    while y < 27:
        y0 = y
        while y < 27 and (col[y] == col[y0]).all():
            y += 1
        runs.append(f"{y0}+{y - y0}")
    out.append("rows " + " ".join(runs))
    out.append("gaps " + " ".join(str(t2[0] - t1[1] - 1) for t1, t2 in zip(tiles, tiles[1:], strict=False)))
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


def art(path, names):
    """Pictures of art/icons.txt by name: {name: list of rows of . and #}."""
    out, name = {}, None
    with open(path, encoding="utf8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("@"):
                name = line[1:].split()[0]
                name = name if name in names else None
                if name:
                    out[name] = []
            elif name and line and set(line) <= {".", "#"}:
                out[name].append(line)
            elif not line:
                name = None
    return out


def tv(icons, folder, label):
    """The faults of one run of tools/regress/tv-frames.sh, and its measured line."""
    frames = art(icons, {f"tv-{i}" for i in range(4)})
    if len(frames) != 4:
        return [f"tv-frames: {icons} has {len(frames)} of the television's four frames"], ""
    shots = sorted(glob.glob(os.path.join(folder, "f-*.png")), key=lambda f: int(os.path.basename(f)[2:-4]))
    if len(shots) < 30:
        return [f"tv-frames ({label}): {len(shots)} shots"], ""
    times = [int(os.path.basename(f)[2:-4]) / 1e6 for f in shots]
    pics = [np.asarray(Image.open(f).convert("RGB"), dtype=np.int16) for f in shots]
    # (the first tile of the strip, what plays: the hairline's first run of columns — the memory,
    # the clock's wings and the rest of the bar move as they please)
    run = np.flatnonzero((pics[0][3] != pics[0][1, 2]).any(axis=1))
    if not len(run):
        return [f"tv-frames ({label}): no tile on the bar's right"], ""
    end = run[np.flatnonzero(np.diff(run) > 1)[0]] if (np.diff(run) > 1).any() else run[-1]
    pics = [a[:, run[0]:end + 1] for a in pics]
    seen, seq = [], []
    for a in pics:
        for i, u in enumerate(seen):
            if np.array_equal(a, u):
                seq.append(i)
                break
        else:
            seen.append(a)
            seq.append(len(seen) - 1)
    faults = []
    if len(seen) != 4:
        moved = np.argwhere(np.any(np.any(np.stack(seen) != seen[0], axis=0), axis=-1))
        where = f"x {moved[:, 1].min()}–{moved[:, 1].max()}, y {moved[:, 0].min()}–{moved[:, 0].max()}" if len(moved) else "nothing moved"
        return [f"tv-frames ({label}): {len(seen)} different pictures, not 4 ({where})"], ""

    def art_diff(i, j):
        return {(r, c) for r, row in enumerate(frames[f"tv-{i}"]) for c, v in enumerate(row) if v != frames[f"tv-{j}"][r][c]}

    def pic_diff(i, j):
        return {(int(r), int(c)) for r, c in np.argwhere(np.any(seen[i] != seen[j], axis=-1))}

    # the art's frames these four pictures are: the one turn that fits, every pair of pictures
    # differing in exactly the art's pixels, one place on the bar for all of them
    turn = None
    for t in range(4):
        d0, p0 = art_diff(t, (t + 1) % 4), pic_diff(0, 1)
        if len(d0) != len(p0) or not d0:
            continue
        dy, dx = min(p0)[0] - min(d0)[0], min(p0, key=lambda q: q[1])[1] - min(d0, key=lambda q: q[1])[1]
        if all(pic_diff(i, j) == {(r + dy, c + dx) for r, c in art_diff((i + t) % 4, (j + t) % 4)} for i in range(4) for j in range(4)):
            turn = t
            break
    if turn is None:
        faults.append(f"tv-frames ({label}): the four pictures are not the art's: what moves is not what art/icons.txt draws")
    # in order: each new picture the next one round (a slow shot of grim's may miss one: only
    # when the time between the two shots is long enough for that)
    changes = [(times[k], seq[k - 1], seq[k]) for k in range(1, len(seq)) if seq[k] != seq[k - 1]]
    for (t1, a, b), prev in zip(changes, [times[0]] + [c[0] for c in changes], strict=False):
        step = (b - a) % 4
        if step != 1 and t1 - prev < 150 * step * 0.8:
            faults.append(f"tv-frames ({label}): picture {a} then {b}, {t1 - prev:.0f} ms after the last change: out of order")
    dwell = sorted(b[0] - a[0] for a, b in zip(changes, changes[1:], strict=False))
    med = dwell[len(dwell) // 2] if dwell else 0
    if not 120 <= med <= 220:
        faults.append(f"tv-frames ({label}): a frame lasts {med:.0f} ms (six a second is 167)")
    return faults, f"{label}: {len(shots)} shots, {len(changes)} changes, {med:.0f} ms a frame"


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
    elif cmd == "tv":
        faults, said = [], []
        for d in argv[3:]:
            f, line = tv(argv[2], d, os.path.basename(d.rstrip("/")))
            faults += f
            said.append(line)
        print("\n".join(faults) if faults else f"tv-frames: held — the art's four frames, in order, no stray pixel · {' · '.join(said)}")
        return 1 if faults else 0
    else:
        sys.exit(__doc__)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
