#!/usr/bin/env python3
"""tools/pixel-options.py — the owner's pixel accents, as options (r28 S3): the real screens (the kit's shots and the picked
mock-ups, the picker pack's) on one 1:1 page per option and mood, the option's pixels drawn on them, one for one: no scaling.
Nothing here is applied to the desktop. P1 separators and rules, P2 the selection marker, P3 corners and frames, P4 the meters.

    python3 tools/pixel-options.py WORK HI  # WORK/wall-MOOD.png, WORK/MOOD/{quick,notice}.png, HI/{h1-1,g-1,f-3}-MOOD.png → HI/P?-N-MOOD.png
    # (the kit: quick by a play, kawa-quick then the pointer at 1672 216, the row hovered; notice by its scene, alone)
    python3 tools/pixel-options.py zoom PAGE X Y W H N OUT  # a part of a page, N times, nearest neighbour: to look at
"""
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

MOODS = ("dark", "light")
PAGE = (1920, 720)
# the tokens of docs/design-system.md; ink: the rule's pixel art wants more than edge2 to be seen at all
TOKENS = {
    "dark": {"edge2": "3c2f22", "ink": "907e5d", "accent": "eb5324", "accent_hi": "f47b58", "outline": "111314", "select": "2e1f19",
             "edge": "2d251e", "asagi": "82c1b4", "flame": "f68c50", "brass": "c5a56e", "brass_hi": "d6c09a", "brass_lo": "746346", "tile": "80735b",
             # new shades, not in the design system yet: a lit bar's top and foot
             "asagi_hi": "b4dcd2", "asagi_lo": "5a9488", "flame_hi": "fab58a", "flame_lo": "c2642f"},
    "light": {"edge2": "d7bc8c", "ink": "96865e", "accent": "a84222", "accent_hi": "cb6336", "outline": "f8f3d8", "select": "e2d0ae",
              "edge": "dfcc9c", "asagi": "00726a", "flame": "a84222", "brass": "e2b540", "brass_hi": "ebcb79", "brass_lo": "957d38", "tile": "343a35",
              "asagi_hi": "2c9d92", "asagi_lo": "00524c", "flame_hi": "cb6336", "flame_lo": "7c2f18"},
}
# what comes from where: the window's box in its shot, and where it sits on the page
SUPER_U = ((56, 56, 762, 334), (20, 60))
POWER = ((6, 18, 468, 172), (20, 360))
NOTICE = ((122, 3, 532, 200), (800, 60))
QUICK = ((1502, 34, 1913, 676), (1502, 42))
BAR_H = 40
# the frames, inclusive, on the page: Super+U, the two notices, quick settings (it hangs from the bar: no top rule). The power menu keeps its rods
WINDOWS = ((20, 60, 725, 337), (800, 60, 1209, 153), (800, 162, 1209, 255), (1502, 42, 1911, 682))
QS_METERS = ((1569, 129, 0.85), (1569, 169, 0.0))   # x, y, level: 40 segments, 320 by 10
LEVELS = (800, 270, 352, 143)                       # the mock-up with what quick settings can't show: x, y, w, h
FONT = "/usr/local/share/fonts/fedokawaii/SumiUI.ttf"


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
        for (_, _, _, y1), (x, w) in zip(rows, words, strict=True):
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


# ---- P3, corners and frames

def corners(box, which="tl tr bl br"):
    """(the corner's x and y, the way in along x, along y) for the corners asked for."""
    x0, y0, x1, y1 = box
    at = {"tl": (x0, y0, 1, 1), "tr": (x1, y0, -1, 1), "bl": (x0, y1, 1, -1), "br": (x1, y1, -1, -1)}
    return [at[k] for k in which.split()]


def stamp(page, corner, rows, inks):
    x, y, sx, sy = corner
    for j, row in enumerate(rows):
        for i, c in enumerate(row):
            if c in inks:
                page.putpixel((x + sx * i, y + sy * j), inks[c])


def tiles(page, mood):
    """The bar's tiles: pairs of columns in the frame's colour, rows 6 to 32. (The clock's rods aren't that colour.)"""
    a = np.asarray(page.crop((0, 6, 1920, 33)))
    edge = np.array(rgb(TOKENS[mood]["tile"]))
    xs = np.nonzero((a == edge).all(axis=2).all(axis=0))[0]
    out = []
    for x0, x1 in zip(xs[::2], xs[1::2], strict=True):
        col = np.asarray(page.crop((int(x0), 0, int(x0) + 1, 40)))
        ys = np.nonzero((col == edge).all(axis=2)[:, 0])[0]
        out.append((int(x0), int(ys[0]) - 1, int(x1), int(ys[-1]) + 1))
    return out


def kakko(page, t, box, leg=14, thick=2):
    """The brackets of Japanese quotation, 「 at the top left and 」 at the bottom right: a window is a thing said."""
    for x, y, sx, sy in corners(box, "tl br"):
        for i in range(leg):
            for k in range(thick):
                page.putpixel((x + sx * i, y + sy * k), t["accent"])
                page.putpixel((x + sx * k, y + sy * i), t["accent"])


def kaidan(page, box, ink, step, n, shade, which="tl tr bl br"):
    """An old game's dialog box: the corner cut in n stairs of step pixels, the rule following them, the ground outside it its neighbour's,
    the straight shadow (shade pixels, right and below) gone beside the cut."""
    for x, y, sx, sy in corners(box, which):
        for i in range(step * n):
            for d in range(1, shade + 1):
                if sy < 0:
                    page.putpixel((x + sx * i, y + d), page.getpixel((x + sx * i, y + shade + 1)))
                if sx < 0:
                    page.putpixel((x + d, y + sy * i), page.getpixel((x + shade + 1, y + sy * i)))
        for j in range(step * n):
            inset = (n - j // step) * step
            for i in range(inset):
                page.putpixel((x + sx * i, y + sy * j), page.getpixel((x - sx * 2, y + sy * j)))
            page.putpixel((x + sx * inset, y + sy * j), ink)
            if j % step == 0:
                for i in range(inset, inset + step + 1):
                    page.putpixel((x + sx * i, y + sy * j), ink)
        for i in range(step + 1):
            page.putpixel((x + sx * i, y + sy * step * n), ink)


# a fitting off an old chest, as the rods' ends on jiku: one arm along each edge, a rivet in the crook
KANAGU = (".hhhhhhhhhh.",
          "hoooooooooos",
          "hoooooooos..",
          "hoo##osss...",
          "hoo##os.....",
          "hooooos.....",
          "hoosss......",
          "hoos........",
          "hoos........",
          "hos.........",
          "ho..........",
          ".s..........")
KANAGU_S = ("hhhh",
            "hos.",
            "hs..",
            "h...")


def p3(page, mood, n):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    bar = tiles(page, mood)
    print(mood, "tiles", bar)
    metal = {"h": t["brass_hi"], "o": t["brass"], "s": t["brass_lo"], "#": t["outline"]}
    for box in WINDOWS:
        if n == 1:
            kakko(page, t, box)
        elif n == 2:
            ink = page.getpixel((box[0] + 40, box[1])) if box[1] > 42 else page.getpixel((box[0], (box[1] + box[3]) // 2))
            kaidan(page, box, ink, 2, 3, 4, "bl br" if box[1] == 42 else "tl tr bl br")
        else:
            for c in corners(box):
                stamp(page, c, KANAGU, metal)
    for box in bar:
        if n == 1:
            kakko(page, t, box, leg=6)
        elif n == 2:
            kaidan(page, box, t["tile"], 1, 2, 1)
        else:
            for c in corners(box):
                stamp(page, c, KANAGU_S, metal)


# ---- P4, the meters: each 320 by 10 at x, y, as today's

def lit(t, u):
    """A level's colours at u of the scale: over 80 %, fire (design-system §3)."""
    k = "flame" if u > 0.8 else "asagi"
    return t[k], t[k + "_hi"], t[k + "_lo"]


def segments(page, t, x, y, level):
    """Today's."""
    for i in range(40):
        c = lit(t, i / 40)[0] if i < round(level * 40) else t["edge"]
        for a in range(6):
            for b in range(10):
                page.putpixel((x + 8 * i + a, y + b), c)


def tairyoku(page, t, x, y, level):
    """An HP bar: a trough in a frame, the rods' brass at its ends, the fill lit from above, its front bright, a notch at each quarter."""
    x1 = x + 319
    for i in range(x, x1 + 1):
        for j in range(y, y + 10):
            page.putpixel((i, j), t["edge2"] if j in (y, y + 9) else t["edge"])
    w = 314
    front = round(w * level)
    for i in range(front):
        body, hi, lo = lit(t, i / w)
        for j in range(8):
            c = hi if j == 0 or i == front - 1 else lo if j >= 6 else body
            page.putpixel((x + 3 + i, y + 1 + j), c)
    for q in (1, 2, 3):
        for j in (1, 2):
            page.putpixel((x + 3 + w * q // 4, y + j), t["edge2"] if w * q // 4 >= front else t["outline"])
            page.putpixel((x + 3 + w * q // 4, y + 9 - j), t["edge2"] if w * q // 4 >= front else t["outline"])
    for i, c in ((x, t["brass_hi"]), (x + 1, t["brass"]), (x + 2, t["brass_lo"]), (x1 - 2, t["brass_hi"]), (x1 - 1, t["brass"]), (x1, t["brass_lo"])):
        for j in range(10):
            page.putpixel((i, y + j), c)


GEM = ("....hh....",
       "...hoos...",
       "..hooooo..",
       ".hoooooos.",
       "hoooooooos",
       "hoooooooos",
       ".ooooooos.",
       "..oooooo..",
       "...ooss...",
       "....ss....")


def hishi(page, t, x, y, level):
    """Twenty lozenges, 5 % each, on a cord: a family crest's hishi, filling from the left."""
    w = 16
    for k in range(20):
        gx = x + 3 + w * k
        body, hi, lo = lit(t, (k + 0.5) / 20)
        part = max(0.0, min(1.0, level * 20 - k))
        for j, row in enumerate(GEM):
            for i, c in enumerate(row):
                if c != ".":
                    on = i < part * 10
                    page.putpixel((gx + i, y + j), {"h": hi, "o": body, "s": lo}[c] if on else t["edge"] if c == "o" else t["edge2"])
        if k < 19:                                  # the cord, to the next
            for i in range(10, w):
                c = lo if part == 1 and level * 20 > k + 1 else t["edge2"]
                page.putpixel((gx + i, y + 4), c)
                page.putpixel((gx + i, y + 5), c)


def katana(page, t, x, y, level):
    """A sword drawn from its scabbard: the hilt and guard stand for nothing, the blade is the scale, its mouth ring the level; the blade curves up, as one does."""
    for i in range(48):                             # the hilt: its wrap in diamonds, a pommel
        for j in range(2, 8):
            c = t["ink"] if (i + j) % 6 < 2 or (i - j) % 6 < 2 else t["edge2"]
            page.putpixel((x + i, y + j), t["brass"] if i < 3 else c)
    for i in range(48, 52):                         # the guard
        for j in range(10):
            if not (i in (48, 51) and j in (0, 9)):
                page.putpixel((x + i, y + j), t["brass_hi"] if i == 48 else t["brass_lo"] if i == 51 else t["brass"])
    n = 268
    front = round(n * level)
    for i in range(n):
        lift = 1 if i >= n * 5 // 8 else 0
        lift += 1 if i >= n * 7 // 8 else 0
        rows = 5 - sum(i >= n - d for d in (14, 9, 5, 2))   # the point, cut from below
        body, hi, lo = lit(t, i / n)
        for r in range(rows):
            yy = y + 3 - lift + r
            if i < front:
                wave = 3 + (i // 7) % 2                     # the hamon, a wave along the edge
                c = lo if r == 0 else hi if r >= wave or r == rows - 1 else body
            else:
                c = t["edge2"] if r == 0 else t["edge"]
            page.putpixel((x + 52 + i, yy), c)
    if 0 < front < n:                               # the scabbard's mouth, brass, sliding with the level
        lift = (front >= n * 5 // 8) + (front >= n * 7 // 8)
        for i in (0, 1):
            for j in range(-1, 6):
                page.putpixel((x + 52 + front + i, y + 3 - lift + j), t["brass_hi"] if i == 0 else t["brass_lo"])


def label(page, x, y, words, ink, anchor="ls"):
    d = ImageDraw.Draw(page)
    d.fontmode = "1"
    d.text((x, y + 14), words, font=ImageFont.truetype(FONT, 14), fill=ink, anchor=anchor)


def p4(page, mood, n):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    draw = (segments, tairyoku, hishi, katana)[n]
    ground = np.asarray(page.crop((1568, 108, 1640, 124))).astype(np.int16)    # the word's own colour, off the shot
    far = np.abs(ground - ground[0, 0]).sum(axis=2)
    text = tuple(int(v) for v in ground[np.unravel_index(far.argmax(), far.shape)])
    for x, y, level in QS_METERS if n else ():      # (today's stay the shot's; their ticks under the quarters go with them: each option counts its own way)
        for j in range(y - 1, y + 15):
            for i in range(x - 2, x + 322):
                page.putpixel((i, j), page.getpixel((i, y - 2)))
        draw(page, t, x, y, level)
    x, y, w, h = LEVELS
    paper = page.getpixel((1000, 240))
    rule = page.getpixel((1000, 162))
    ImageDraw.Draw(page).rectangle((x, y, x + w - 1, y + h - 1), fill=paper, outline=rule)
    for cx, cy, _, _ in corners((x, y, x + w - 1, y + h - 1)):
        page.putpixel((cx, cy), page.getpixel((cx + (-1 if cx == x else 1), cy)))
    for k, (name, level, value) in enumerate((("volume", 0.62, "62%"), ("battery", 0.15, "15%"), ("downloads", 0.38, "38% · 3 min"))):
        top = y + 16 + 40 * k
        label(page, x + 16, top, name, text)
        label(page, x + 336, top, value, text, "rs")
        if name == "battery":                       # (low, by the same fire)
            f = dict(t, asagi=t["flame"], asagi_hi=t["flame_hi"], asagi_lo=t["flame_lo"])
            draw(page, f, x + 16, top + 21, level)
        else:
            draw(page, t, x + 16, top + 21, level)


def main(work, hi):
    for m in MOODS:
        for n in range(4):
            for name, fn in (("P1", p1), ("P2", p2), ("P3", p3), ("P4", p4)):
                page = base(work, hi, m)
                if n or name == "P4":
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
