#!/usr/bin/env python3
"""tools/panel-measure.py RAW — the menus' and panels' pixels measured from their shots (tools/panel-review.sh's raw/THEME/*.png),
against docs/design-system.md §3–§4: each surface's frame on the screen, each row's ink — its picture, name, value, marks — from the
frame and from the row's place; the cursor's yubi. Prints a markdown table of what was measured and what the design asks; exit 1 if any differs.
Needs numpy and Pillow."""
import os
import sys

import numpy as np
from PIL import Image

X0 = 17                                  # hairline + pad
BAD = []


def load(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)


def ink(a, x, y, w, h, bg):
    """The ink in x, y, w, h that is not bg (and not any colour in bg's list): [xs], [ys] as absolute."""
    r = a[y:y + h, x:x + w]
    mask = np.ones(r.shape[:2], bool)
    for b in bg:
        mask &= np.any(r != np.array(b, dtype=np.int16), axis=2)
    ys, xs = np.nonzero(mask)
    return xs + x, ys + y


def spans(xs, gap=5):
    """Sorted x's as runs apart by more than gap px."""
    out = []
    for v in sorted(set(int(q) for q in xs)):
        if out and v - out[-1][1] <= gap:
            out[-1][1] = v
        else:
            out.append([v, v])
    return out


def colour(a, x, y):
    return tuple(int(v) for v in a[y, x])


def frame_of(a, ground):
    """The frame: the largest box not the ground below the bar's rows (its hairlines, corners out)."""
    xs, ys = ink(a, 0, 28, a.shape[1], a.shape[0] - 28, [ground])
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def want(table, surface, what, got, need):
    ok = got == need
    if not ok:
        BAD.append(f"{surface}: {what}: {got}, the design {need}")
    table.append((surface, what, got, need, "✔" if ok else "✘"))


def quick(a, table, th, ground, cursor=None):
    s = f"quick settings ({th})"
    # the frame: the right hairline on x 1911, the top on y 44 (§6)
    col = [y for y in range(28, a.shape[0]) if colour(a, 1600, y) != ground]
    fy = col[0]
    row = [x for x in range(a.shape[1]) if colour(a, x, 300) != ground]
    fx = row[0]
    want(table, s, "top hairline y", fy, 44)
    fw = 410
    want(table, s, "right hairline x", fx + fw - 1, 1911)
    x0 = fx + X0
    # (tools/panel-review.sh's machine: the five sections, share sound and the lights among them)
    rows = {"theme": 173, "night": 193, "dnd": 213, "saver": 233, "vrr": 253, "wallpaper": 273, "sharesound": 321, "network": 369,
            "bluetooth": 389, "devices": 409, "drives": 429, "backup": 449, "screenshot": 497, "record": 517, "ocr": 537, "rgb": 585,
            "screenoff": 605, "power": 625}
    labels = (153, 301, 349, 477, 565)
    if cursor is not None:                 # (a row with the cursor: yubi's own checks, yubi())
        rows = {k: v for k, v in rows.items() if v != cursor}
    left, names, right, cys = [], [], [], []
    for ry in rows.values():
        y = fy + ry
        xs, ys = ink(a, x0, y, 376, 20, [ground])
        if not len(xs):
            continue
        sp = spans(xs, gap=6)
        ixs = [v for v in xs if x0 <= v < x0 + 28]
        left.append(min(ixs) - x0)
        iys = [int(q) for q, v in zip(ys, xs, strict=True) if x0 <= v < x0 + 28]
        cys.append((min(iys) + max(iys)) / 2 - y)
        nxs = [v for v in xs if x0 + 28 <= v < x0 + 36]
        names.append(min(nxs) - x0 if nxs else None)
        right.append(x0 + 376 - 1 - sp[-1][1])
    want(table, s, "rows: a picture's ink from the row's left, least", min(left), 8)
    want(table, s, "rows: a picture's ink within the 16 px column", max(left) <= 16, True)
    want(table, s, "rows: the words' first ink, x0 + (one column; a letter's own bearing, 32–34)", set(int(n) for n in names if n is not None) <= {32, 33, 34}, True)
    want(table, s, "rows: the marks' or value's end, from the row's right", min(right), 8)
    want(table, s, "rows: a picture's ink centred on the row, ±1 of 9.5", all(abs(c - 9.5) <= 1 for c in cys), True)
    # the instrument's ink
    y = fy + 65
    xs, ys = ink(a, x0 + 8, y, 32, 40, [ground])
    want(table, s, "lantern within x0 + 8 … + 39", (bool(min(xs) >= x0 + 8), bool(max(xs) <= x0 + 39)), (True, True))
    # the meter: its first and last segment
    my = y + 23 + 2
    run = [x for x in range(x0, x0 + 376) if colour(a, x, my) != ground and x >= x0 + 48]
    want(table, s, "the meter's first segment x0 +", run[0] - x0, 50)
    want(table, s, "the meter's last ink, from the row's right", x0 + 376 - 1 - run[-1], 8)
    xs, _ = ink(a, x0 + 48, y, 60, 20, [ground])
    want(table, s, "the name's first ink, x0 + (over the meter's first segment)", int(xs.min()) - x0, 50)
    # the masthead: the plate 10 px out of the content, the head in it, the words on the meter's first segment
    px, py = x0 - 10, fy + X0 - 10
    plate = colour(a, px + 62, py + 3)
    # (its box by runs from the panel's paper: the frame's brass corners, kanagu, stand in the box round it)
    mid = fy + 1 + 26
    hx = [x for x in range(fx + 1, fx + 409) if colour(a, x, mid) != ground]
    vy = [y for y in range(fy + 1, fy + 80) if colour(a, x0 + 200, y) != ground]
    pl, pr, t = hx[0], hx[-1], vy[0]
    b = t
    while colour(a, x0 + 200, b + 1) != ground:
        b += 1
    want(table, s, "the plate's box, x0 +", (pl - x0, pr - x0 + 1), (-10, 386))
    want(table, s, "the plate's rows and its lip", b - t + 1, 53)
    want(table, s, "the air over the plate, under the panel's frame", t - fy - 1, 6)
    want(table, s, "the air left of the plate, inside the panel's frame", pl - fx - 1, 6)
    want(table, s, "the air right of the plate, inside the panel's frame", fx + 409 - pr - 1, 6)
    xs, ys = ink(a, px + 1, py + 1, 57, 50, [plate])
    want(table, s, "the head: inside x0 - 8 … + 39, y inside the plate's frame", (bool(int(xs.min()) >= x0 - 8), bool(int(xs.max()) <= x0 + 39)), (True, True))
    xs, _ = ink(a, px + 58, py + 2, 100, 26, [plate])
    want(table, s, "the name's first ink on the plate, x0 + (over the meter's)", int(xs.min()) - x0, 50)
    # the marks: every row's last cap ends on the same column, every seal against it, 2 px apart (the two rows that have both)
    if cursor is None:
        fill = {}
        for k in ("night", "saver"):
            y = fy + rows[k]
            xs, _ = ink(a, x0 + 300, y, 76, 20, [ground])
            sp = spans(xs, gap=1)
            fill[k] = (sp[-2][1] - sp[-2][0] + 1, sp[-1][0] - sp[-2][1] - 1, x0 + 376 - 1 - sp[-1][1])
        for k, got in fill.items():
            want(table, s, f"{k}: the seal's width, its gap to the key, the key's end from the row's right", got, (16, 2, 8))
        ends = sorted({x0 + 376 - 1 - spans(ink(a, x0 + 300, fy + rows[k], 76, 20, [ground])[0], gap=1)[-1][1] for k in rows})
        want(table, s, "every row's key ends on one column, from the row's right", ends, [8])
    # labels: the rule ends on the row's end
    for y in labels:
        rule_y = fy + y + 10
        rx = [x for x in range(x0, x0 + 376) if colour(a, x, rule_y) != ground]
        want(table, s, f"the label at {y}: the rule's end, x0 +", rx[-1] - x0 + 1, 376)


YUBI = ("##......",                       # kawa-panel's YUBI: "#" yubi_rim, "o" select_edge, "h" accent_hi, "." the ground
        "#o#.....",
        "#oh#....",
        "#ooh#...",
        "#oooo#..",
        "#ooo#...",
        "#oo#....",
        "#o#.....",
        "##......")


def yubi(a, table, s, fx, y, ground, conf):
    """A row with the cursor at y: no band (select is the ground, §2); yubi, the 8 x 9 pointer, x0 - 11 + its pose (0 1 2 1)
    on the row's rows 6-14, and the row's name in text_on_select."""
    def rgb(k):
        return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
    x0 = fx + X0
    want(table, s, "no band: select is the ground", rgb("select"), ground)
    ink_of = {"#": rgb("yubi_rim"), "o": rgb("select_edge"), "h": rgb("accent_hi"), ".": ground}
    def drawn(x):
        return all(colour(a, x + i, y + 6 + j) == ink_of[c] for j, ln in enumerate(YUBI) for i, c in enumerate(ln))
    pose = [b for b in (0, 1, 2) if drawn(x0 - 11 + b)]
    want(table, s, "yubi drawn whole, its left x0 - 11 + a pose (0 1 2)", len(pose) == 1, True)
    if pose:                                 # (its gutter beside it: only the ground, the 2 px either side of the pose)
        gx = [x for x in range(x0 - 13, x0) if not x0 - 11 + pose[0] <= x < x0 - 3 + pose[0]]
        want(table, s, "yubi's gutter, the rest: the ground", all(colour(a, x, q) == ground for x in gx for q in range(y, y + 20)), True)
    xs, ys = ink(a, x0, y, 376, 20, [ground])
    cols = {colour(a, int(x), int(q)) for x, q in zip(xs, ys, strict=True)}
    want(table, s, "the row's ink: text_on_select in it", rgb("text_on_select") in cols, True)


def box_of(a, ground, top=28):
    """The bounds of what is not the (dimmed) ground under the bar's rows."""
    xs, ys = ink(a, 0, top, a.shape[1], a.shape[0] - top, [ground])
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def power(a, table, th, conf):
    """The power dialog: a hanging scroll (sa16), its frame between two rods 14 wide, centred on the screen; five seal
    tiles 64 square, 12 apart and 28 before restart (what asks twice stands apart); under each its word, under that
    its key's cap; the foot centred."""
    s = f"the power dialog ({th})"
    def rgb(k):
        return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
    hi = np.all(a == np.array(rgb("rod_hi"), dtype=np.int16), axis=2)
    cols = [x for x in range(a.shape[1]) if hi[:, x].sum() >= 100]
    rods = spans(cols, gap=1)
    want(table, s, "two rods, their light 2 px wide", [r[1] - r[0] + 1 for r in rods], [2, 2])
    if len(rods) != 2:
        return
    lx, rx = rods[0][0] - 6, rods[1][0] - 6                      # (a rod's bands: 1 2 3, then its light)
    band = [colour(a, lx + i, 540) for i in range(14)]
    names = ("rod_end", "rod_lo", "rod_lo", "rod", "rod", "rod", "rod_hi", "rod_hi", "rod", "rod", "rod", "rod_lo", "rod_lo", "rod_end")
    want(table, s, "the left rod's bands", band == [rgb(n) for n in names], True)
    want(table, s, "the right rod's bands", [colour(a, rx + i, 540) for i in range(14)] == [rgb(n) for n in names], True)
    ys = np.nonzero(hi[:, rods[0][0]])[0]
    fx, fy, W, H = lx + 14, int(ys.min()) - 2, rx - lx - 14, int(ys.max()) - int(ys.min()) + 1 + 4
    want(table, s, "the rods either side of the frame, its hairlines between them", (colour(a, fx, 540) not in band, colour(a, fx + W - 1, 540) not in band), (True, True))
    want(table, s, "centred across: left and right of the frame", fx, 1920 - fx - W)
    want(table, s, "centred down: above and below the frame", fy, 1080 - fy - H)
    cap = [y for y in range(fy - 10, fy + 2) if colour(a, lx + 7, y) in (rgb("cap"), rgb("cap_lo"), rgb("cap_hi"))]
    want(table, s, "the rod's cap: its first row over the frame's", fy - cap[0] if cap else None, 6)
    # the tiles: their row's first ink, 17 px in; then the five along their middle
    g = colour(a, fx + 6, fy + 6)                                # (the scroll's paper)
    xs, ys = ink(a, fx + 4, fy + 3, W - 8, H - 6, [g])
    ty = int(ys.min())
    want(table, s, "the tiles' top, from the frame's top (hairline + pad)", ty - fy, 17)
    run = spans(ink(a, fx + 4, ty + 32, W - 8, 1, [g])[0], gap=1)
    want(table, s, "five tiles, 64 wide", [r[1] - r[0] + 1 for r in run], [64] * 5)
    want(table, s, "the air between them (restart apart)", [run[k + 1][0] - run[k][1] - 1 for k in range(len(run) - 1)], [12, 12, 28, 12])
    want(table, s, "the row centred in the frame: air left, right", run[0][0] - fx, fx + W - 1 - run[-1][1])
    if len(run) != 5:
        return
    want(table, s, "the tile under the cursor: inked", colour(a, run[0][0] + 5, ty + 5), rgb("accent"))
    want(table, s, "the others blank: the key's paper in edge2's rim", all(colour(a, r[0] + 5, ty + 5) == rgb("key") and colour(a, r[0], ty + 32) == rgb("edge2") for r in run[1:]), True)
    tops = set()
    for k, (tx, _) in enumerate(run):
        inner = colour(a, tx + 6, ty + 6)                         # (the tile's paper)
        xs, ys = ink(a, tx + 6, ty + 6, 52, 52, [inner])
        dx = (int(xs.min()) + int(xs.max())) / 2 - (tx + 31.5)
        dy = (int(ys.min()) + int(ys.max())) / 2 - (ty + 31.5)
        want(table, s, f"tile {k + 1}: its picture centred, within a pixel", (abs(dx) <= 1, abs(dy) <= 1), (True, True))
        xs, _ = ink(a, tx - 6, ty + 64 + 8, 76, 20, [g])
        dx = (int(xs.min()) + int(xs.max())) / 2 - (tx + 31.5)
        want(table, s, f"tile {k + 1}: its word centred under it, within a pixel", abs(dx) <= 1, True)
        want(table, s, f"tile {k + 1}: its word within the tile's width", (int(xs.min()) >= tx, int(xs.max()) <= tx + 63), (True, True))
        xs, ys = ink(a, tx - 6, ty + 64 + 8 + 20, 76, 20, [g])
        want(table, s, f"tile {k + 1}: its key's cap centred under the word, within a pixel", abs((int(xs.min()) + int(xs.max())) / 2 - (tx + 31.5)) <= 1, True)
        tops.add(int(ys.min()) - ty)
    want(table, s, "the caps on one row, its top from the tiles' (64 + 8, a row, the cap's 2)", sorted(tops), [64 + 8 + 20 + 2])
    xs, _ = ink(a, fx + 17, ty + 64 + 8 + 40 + 8, W - 34, 20, [g])
    want(table, s, "the foot centred, within a pixel", abs((int(xs.min()) + int(xs.max())) / 2 - (fx + (W - 1) / 2)) <= 1, True)


def calendar(a, table, th, conf, ground):
    s = f"the calendar ({th})"
    def rgb(k):
        return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
    x0_, y0_, x1_, y1_ = box_of(a, ground, 44)
    W = 362
    want(table, s, "the frame's top y", y0_, 44)
    want(table, s, "the frame's width", x1_ - x0_, W)
    want(table, s, "centred on the screen's middle: left, right of the frame", x0_, 1920 - x0_ - W)
    # the grid: 40 × 20, 8 apart
    ground2 = colour(a, x0_ + 6, y0_ + 6)
    for label, col, ink_ in (("Saturday", 5, "ai"), ("Sunday", 6, "accent_text")):
        cx = x0_ + 17 + col * 48
        xs, ys = ink(a, cx, y0_ + 45, 40, 20, [ground2])
        cols = {colour(a, int(x), int(y)) for x, y in zip(xs, ys, strict=True)}
        want(table, s, f"{label}'s head in its ink", rgb(ink_) in cols, True)
    # today: a filled seal 20 × 20, centred in its cell
    acc = rgb("accent")
    reg = a[y0_ + 60:y0_ + 200, x0_ + 17:x0_ + 345]
    hit = np.all(reg == np.array(acc, dtype=np.int16), axis=2)
    runs = [(y, x) for y in range(hit.shape[0]) for x in range(hit.shape[1] - 16) if hit[y, x:x + 16].all() and (x == 0 or not hit[y, x - 1])]
    if runs:                                   # (a run 16 px long: no digit's ink has one)
        ys = [y for y, _ in runs]
        x = min(x for _, x in runs)
        h = max(ys) - min(ys) + 1
        w = max(int(hit[y, x:x + 24].sum()) for y in ys)
        want(table, s, "today's seal", (w, h), (20, 20))
        col = (x + 10) // 48
        want(table, s, "today's seal centred in its 40 px cell", x - col * 48, 10)
    # the footer: the first cap at the rows' inset
    xs, ys = ink(a, x0_ + 17, y1_ - 2 - 17 - 19, 328, 20, [ground2])
    want(table, s, "the footer's first cap, x0 +", int(xs.min()) - (x0_ + 17), 8)


def rows_of(a, table, s, fx, fy, keys, ground):
    """A menu's rows at y (from the frame's top): the marks' or the values' end from the row's right, the pictures' start from its left."""


def notice(a, table, th, conf, ground):
    s = f"the critical notice ({th})"
    def rgb(k):
        return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
    xs, _ = ink(a, 0, 44, a.shape[1], a.shape[0] - 44, [ground])
    if not len(xs):                          # (no notice: the kit's mako is older than configs/home/.config/mako)
        want(table, s, "drawn (panel-review --mako: a build of src/mako/mako.patch)", False, True)
        return
    x0_, y0_, x1_, y1_ = box_of(a, ground, 44)
    hx = [x for x in range(x1_ - 4, x1_ + 1) if colour(a, x, y0_ + 30) == rgb("accent")]       # (a column of shadow beyond)
    want(table, s, "the right hairline x", hx[-1] if hx else None, 1911)
    want(table, s, "the top hairline y", y0_, 44)
    run = [x for x in range(x0_, x0_ + 12) if colour(a, x, y0_ + 30) == rgb("accent")]
    want(table, s, "the left: its hairline and the 3 px bar", len(run), 4)
    reg = a[y0_ + 10:y0_ + 45, x0_ + 8:x0_ + 50]
    ys, xs = np.nonzero(np.all(reg == np.array(rgb("accent"), dtype=np.int16), axis=2))
    want(table, s, "the title's seal", (int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)) if len(xs) else None, (18, 18))


def system(a, table, th, conf, ground):
    s = f"Super+U ({th})"
    def rgb(k):
        return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
    # the cursor: a terminal list's, no band (select is the ground); a 2 px edge, 20 rows, at its first column (§4, §10)
    m = np.all(a == np.array(rgb("select_edge"), dtype=np.int16), axis=2)
    xs, ys = ink(a, 0, 44, a.shape[1], a.shape[0] - 44, [ground])
    wx = int(xs.min())                       # (the window's left hairline: the edge stands in its first columns, not a red word)
    m[:44] = False                           # (the bar's)
    m[:, :wx + 2] = False
    m[:, wx + 40:] = False
    two = m[:, 1:-2] & m[:, 2:-1] & ~m[:, :-3] & ~m[:, 3:]
    runs = []                                # (x, top, rows) of each column's runs: the edge a long one, a red picture's strokes short
    for x in sorted(set(np.nonzero(two)[1].tolist())):
        col = two[:, x]
        y = 0
        while y < len(col):
            if col[y]:
                y1 = y
                while y1 < len(col) and col[y1]:
                    y1 += 1
                runs.append((x, y, y1 - y))
                y = y1
            y += 1
    long = [r for r in runs if r[2] >= 10]
    want(table, s, "the cursor's edge: one, 2 px wide", len(long), 1)
    if not long:
        return
    band_l, y0, rows = long[0][0] + 1, long[0][1], long[0][2]
    want(table, s, "the edge's rows", rows, 20)
    xs2, _ = ink(a, band_l + 2, y0, 400, 20, [ground])
    sp = spans(xs2, gap=9)
    want(table, s, "the icon's first ink from the edge's left (two cells)", sp[0][0] - band_l >= 16, True)


def main():
    raw = sys.argv[1]
    table = []
    for th in ("dark", "light"):
        d = os.path.join(raw, th)
        conf = dict(ln.strip().split("=") for ln in open(f"configs/home/.config/fedokawaii/themes/{th}/panel.conf") if "=" in ln and not ln.startswith("#"))
        def rgb(k, conf=conf):
            return tuple(int(conf[k][i:i + 2], 16) for i in (0, 2, 4))
        a = load(f"{d}/quick.png")
        g = colour(a, 1600, 300)              # (the panel's own ground over the kit's)
        quick(a, table, th, g)
        c = load(f"{d}/quick-cursor.png")
        fx = [x for x in range(c.shape[1]) if colour(c, x, 300) != colour(c, 1600, 300)][0]
        yubi(c, table, f"the cursor ({th})", fx, 44 + 193, colour(c, 1600, 300), conf)
        power(load(f"{d}/power.png"), table, th, conf)
        kit = rgb("ground")
        calendar(load(f"{d}/calendar.png"), table, th, conf, kit)
        notice(load(f"{d}/notice-critical.png"), table, th, conf, kit)
        for n in ("system", "system-1", "system-3", "system-4"):
            system(load(f"{d}/{n}.png"), table, th, conf, kit)
    print("| surface | what | measured | design | |\n|---|---|---|---|---|")
    for r in table:
        print("| " + " | ".join(str(v) for v in r) + " |")
    if BAD:
        print("\n".join(BAD), file=sys.stderr)
    return 1 if BAD else 0


if __name__ == "__main__":
    sys.exit(main())
