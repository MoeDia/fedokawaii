#!/usr/bin/env python3
"""tools/pixel-options.py — the owner's pixel accents, as options (r28 S3): the real screens (the kit's shots and the picked
mock-ups, the picker pack's) on one 1:1 page per option and mood, the option's pixels drawn on them, one for one: no scaling.
Nothing here is applied to the desktop. P1 separators and rules, P2 the selection marker.

    python3 tools/pixel-options.py WORK HI  # WORK/wall-MOOD.png, WORK/MOOD/{quick,notice}.png, HI/{h1-1,g-1,f-3}-MOOD.png → HI/P?-N-MOOD.png
    # (the kit: quick by a play, kawa-quick then the pointer at 1672 216, the row hovered; notice by its scene, alone)
    python3 tools/pixel-options.py zoom PAGE X Y W H N OUT  # a part of a page, N times, nearest neighbour: to look at
"""
import pathlib
import sys

import numpy as np
from PIL import Image

MOODS = ("dark", "light")
PAGE = (1920, 720)
# the tokens of docs/design-system.md; ink: the rule's pixel art wants more than edge2 to be seen at all
TOKENS = {
    "dark": {"edge2": "3c2f22", "ink": "907e5d", "accent": "eb5324", "accent_hi": "f47b58", "outline": "111314", "select": "2e1f19"},
    "light": {"edge2": "d7bc8c", "ink": "96865e", "accent": "a84222", "accent_hi": "cb6336", "outline": "f8f3d8", "select": "e2d0ae"},
}
# what comes from where: the window's box in its shot, and where it sits on the page
SUPER_U = ((56, 56, 762, 334), (20, 60))
POWER = ((6, 18, 468, 172), (20, 360))
NOTICE = ((122, 3, 532, 200), (800, 60))
QUICK = ((1502, 34, 1913, 676), (1502, 42))
BAR_H = 40


def rgb(token):
    return tuple(bytes.fromhex(token))


def base(work, hi, mood):
    work, hi = pathlib.Path(work), pathlib.Path(hi)
    page = Image.open(work / f"wall-{mood}.png").convert("RGB").crop((0, 0, *PAGE))
    page.paste(Image.open(hi / f"f-3-{mood}.png").convert("RGB").crop((0, 0, 1920, BAR_H)), (0, 0))
    for f, (box, at) in ((hi / f"h1-1-{mood}.png", SUPER_U), (hi / f"g-1-{mood}.png", POWER),
                         (work / mood / "notice.png", NOTICE), (work / mood / "quick.png", QUICK)):
        page.paste(Image.open(f).convert("RGB").crop(box), at)
    return page


def rules(page, mood, box):
    """The solid 1 px rules in a window: (x0, x1, y), edge2 for 50 px and more, not edge2 above and below."""
    a = np.asarray(page.crop(box)).astype(np.int16)
    near = np.abs(a - np.array(rgb(TOKENS[mood]["edge2"]))).max(axis=2) <= 12
    out = []
    for y in range(1, a.shape[0] - 1):
        x = 0
        while x < a.shape[1]:
            if near[y, x] and not near[y - 1, x] and not near[y + 1, x]:
                s = x
                while x < a.shape[1] and near[y, x] and not near[y - 1, x] and not near[y + 1, x]:
                    x += 1
                if x - s >= 50:
                    out.append((box[0] + s, box[0] + x - 1, box[1] + y))
            else:
                x += 1
    return out


def band(page, mood, box):
    """The selected row's box: the select colour's extent, on its widest rows."""
    a = np.asarray(page.crop(box)).astype(np.int16)
    near = np.abs(a - np.array(rgb(TOKENS[mood]["select"]))).max(axis=2) <= 6
    ys = np.nonzero(near.sum(axis=1) > 100)[0]
    ys = max(np.split(ys, np.nonzero(np.diff(ys) > 1)[0] + 1), key=len)     # (the wall through the panel can match a stray row)
    xs = np.nonzero(near[ys].sum(axis=0) > 10)[0]
    return box[0] + xs[0], box[1] + ys[0], box[0] + xs[-1], box[1] + ys[-1]


def bitmap(page, x, y, rows, inks):
    """rows: strings, a character per pixel; inks: character → colour; anything else is left as it is."""
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            if c in inks:
                page.putpixel((x + i, y + j), inks[c])


# ---- P1, the rules

def kasumi(page, x0, x1, y, ink, flip=False):
    """Mist: solid, then thinning by ordered dither to nothing, with a thread above and below where it thins."""
    n = x1 - x0 + 1
    solid = n * 45 // 100
    steps = (2, 2, 3, 4, 6)                         # one pixel in each so many
    for i in range(n):
        x = x1 - i if flip else x0 + i
        if i < solid:
            page.putpixel((x, y), ink)
            continue
        s = (i - solid) * len(steps) // (n - solid)
        if i % steps[s] == 0:
            page.putpixel((x, y), ink)
        if s < 3 and i % 4 == 2:
            page.putpixel((x, y - 1 if i % 8 == 2 else y + 1), ink)


WAVE = ("...##...",
        ".##..##.",
        "#..##..#",
        "#.#..#.#",
        "##....##")


def nami(page, x0, x1, y, ink, flip=False):
    """A band of pixel seigaiha, 5 rows, an arc inside each wave, whole waves only, the rule's row its third."""
    n = (x1 - x0 + 1) // 8
    for k in range(n):
        x = x1 - 8 * (k + 1) + 1 if flip else x0 + 8 * k
        bitmap(page, x, y - 2, WAVE, {"#": ink})


CREST = ("...#...",
         "..###..",
         ".##.##.",
         "##.#.##",
         ".##.##.",
         "..###..",
         "...#...")


def mon(page, x0, x1, y, ink, accent, flip=False, crest=True):
    """Solid with stepped end caps, a crest at its middle, two dots either side of it."""
    for x in range(x0 + 2, x1 - 1):
        page.putpixel((x, y), ink)
    for x, s in ((x0, 1), (x1, -1)):
        for d in (-2, -1, 0, 1, 2):
            page.putpixel((x, y + d), ink)
        for d in (-1, 0, 1):
            page.putpixel((x + s, y + d), ink)
    if crest:
        m = (x0 + x1) // 2
        for x in range(m - 9, m + 10):              # the crest's air, and its dots
            page.putpixel((x, y), page.getpixel((x, y - 2)))
        for d in (6, 8):
            page.putpixel((m - d, y), ink)
            page.putpixel((m + d, y), ink)
        bitmap(page, m - 3, y - 3, CREST, {"#": accent})


def p1(page, mood, n):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    lines = []
    for (box, at) in (SUPER_U, QUICK):
        w = box[2] - box[0], box[3] - box[1]
        for x0, x1, y in rules(page, mood, (at[0], at[1], at[0] + w[0], at[1] + w[1])):
            if y < at[1] + 20:                      # (the plate on top of quick settings has an edge of that colour)
                continue
            for x in range(x0, x1 + 1):             # the old rule gone: the ground above it, the wall running through
                page.putpixel((x, y), page.getpixel((x, y - 1)))
            lines.append((x0, x1, y, False))
    # where there is no rule today: a notice's title (a heading's grammar, §4), the power menu's words, either side of the bar's clock
    nx, ny = NOTICE[1][0] - NOTICE[0][0], NOTICE[1][1] - NOTICE[0][1]
    lines += [(nx + 244, nx + 516, ny + 31, False), (nx + 204, nx + 516, ny + 133, False)]
    lines.append((POWER[1][0] + 18, POWER[1][0] + 438, POWER[1][1] + 114, False))
    bar = [(668, 788, 20, True), (1132, 1252, 20, False)]
    for x0, x1, y, flip in lines + bar:
        if n == 1:
            kasumi(page, x0, x1, y, t["ink"], flip)
        elif n == 2:
            nami(page, x0, x1, y, t["ink"], flip)
        else:
            mon(page, x0, x1, y, t["ink"], t["accent"], flip, crest=x1 - x0 > 100)
    return len(lines) + len(bar)


# ---- P2, the marker

POINTER = ("##......",
           "#o#.....",
           "#oh#....",
           "#ooh#...",
           "#oooo#..",
           "#ooo#...",
           "#oo#....",
           "#o#.....",
           "##......")


def turned(rows, down=True):
    w, h = len(rows[0]), len(rows)
    r = ["".join(rows[y][x] for y in (range(h) if down else range(h - 1, -1, -1))) for x in range(w)]
    return r if down else r[::-1]


def pointer(page, t, x, y, turn=None):
    rows = POINTER if turn is None else turned(POINTER, turn == "down")
    bitmap(page, x, y, rows, {"#": t["outline"], "o": t["accent"], "h": t["accent_hi"]})


def fude(page, t, x0, x1, y):
    """A brush's stroke, 3 rows: a loaded start, a dry tail; its gaps fixed, the same stroke every time for a length."""
    n = x1 - x0 + 1
    for i in range(n):
        x, u = x0 + i, i / n
        if u < 0.92 or i % 2 == 0:
            page.putpixel((x, y + 1), t["accent"])
        if 0.02 < u < 0.62 or (u < 0.8 and i % 3):
            page.putpixel((x, y), t["accent"])
        if 0.04 < u < 0.34 or (u < 0.5 and i % 4 == 1):
            page.putpixel((x, y + 2), t["accent"])


def kagi(page, t, x0, y0, x1, y1):
    """Corner brackets around a row: 2 px thick, the outer corner's pixel cut."""
    legs = 6
    for sx, x in ((1, x0), (-1, x1)):
        for sy, y in ((1, y0), (-1, y1)):
            for i in range(1, legs):
                for k in (0, 1):
                    page.putpixel((x + sx * i, y + sy * k), t["accent"])
                    page.putpixel((x + sx * k, y + sy * i), t["accent"])
            page.putpixel((x + sx, y + sy), t["accent"])


def p2(page, mood, n):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    # the selected row of each list: Super+U's and quick settings' measured; the power menu's tile, the bar's tag and the notice's title from their shots
    rows = []
    for box, at in (SUPER_U, QUICK):
        w = box[2] - box[0], box[3] - box[1]
        rows.append(band(page, mood, (at[0], at[1], at[0] + w[0], at[1] + w[1])))
    print(mood, "bands", [tuple(int(v) for v in r) for r in rows])
    words = [(rows[0][0] + 40, 56), (rows[1][0] + 33, 30)]   # (each band's label: its first column, its width)
    tile = (POWER[1][0] + 38, POWER[1][1] + 20, POWER[1][0] + 102, POWER[1][1] + 84)
    tag = (64, 6, 98, 34)
    title = (NOTICE[1][0] + 16, NOTICE[1][1] + 120, NOTICE[1][0] + 76, NOTICE[1][1] + 140)
    if n == 1:
        for x0, y0, _, y1 in rows:
            pointer(page, t, x0 - 11, (y0 + y1) // 2 - 4)     # (in the gutter, at the row's red edge: never on its icon)
        pointer(page, t, tile[0] + 28, tile[1] - 12, "down")
        pointer(page, t, tag[0] + 13, tag[3] + 2, "up")
        pointer(page, t, title[0] - 11, title[1] + 6)
    elif n == 2:
        for (_, _, _, y1), (x, w) in zip(rows, words):
            fude(page, t, x, x + w + 8, y1 - 2)
        fude(page, t, tile[0] + 16, tile[0] + 54, tile[3] + 21)
        fude(page, t, tag[0], tag[2], tag[3] + 2)
        fude(page, t, title[0], title[2] - 2, title[3] - 1)
    elif n == 3:
        for x0, y0, x1, y1 in rows:
            kagi(page, t, x0 - 4, y0 - 1, x1 + 3, y1 + 1)
        kagi(page, t, tile[0] - 4, tile[1] - 4, tile[2] + 3, tile[3] + 3)
        kagi(page, t, tag[0] - 3, tag[1] - 3, tag[2] + 3, tag[3] + 3)
        kagi(page, t, title[0] - 4, title[1], title[2], title[3])


def main(work, hi):
    for m in MOODS:
        for n in range(4):
            for name, fn in (("P1", p1), ("P2", p2)):
                page = base(work, hi, m)
                if n:
                    fn(page, m, n)
                out = pathlib.Path(hi) / f"{name}-{n}-{m}.png"
                page.save(out, optimize=True)
                print(out.name, page.size, out.stat().st_size)
                if out.stat().st_size > 3_000_000:
                    sys.exit(f"{out}: over 3 MB")


def zoom(src, x, y, w, h, n, out):
    x, y, w, h, n = int(x), int(y), int(w), int(h), int(n)
    Image.open(src).convert("RGB").crop((x, y, x + w, y + h)).resize((w * n, h * n), Image.NEAREST).save(out)


if __name__ == "__main__":
    if sys.argv[1] == "zoom":
        zoom(*sys.argv[2:])
    else:
        main(*sys.argv[1:])
