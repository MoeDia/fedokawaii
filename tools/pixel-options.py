#!/usr/bin/env python3
"""tools/pixel-options.py — the owner's pixel accents, as options (r28 S3): the real screens (the kit's shots and the picked
mock-ups, the picker pack's) on one 1:1 page per option and mood, the option's pixels drawn on them, one for one: no scaling.
Nothing here is applied to the desktop. P1 separators and rules, P2 the selection marker, P3 corners and frames, P4 the meters,
P5 small accents; PA all together, the favourite; P2m, P4m, P5m what moves, as MP4s at 2x (x264's 4:2:0 keeps a colour's edge whole only at 2x).

    python3 tools/pixel-options.py WORK HI  # WORK/wall-MOOD.png, WORK/MOOD/{quick,notice}.png, HI/{h1-1,g-1,f-3}-MOOD.png → HI/P?-N-MOOD.png, HI/PA-MOOD.png
    python3 tools/pixel-options.py games WORK HI     # S4, the game-like options: HI/P1-{4..7}-MOOD.png, nothing else rewritten
    python3 tools/pixel-options.py motions WORK HI   # HI/P2m-1-MOOD, P4m-N-MOOD, P5m-2-MOOD, P5m-3-MOOD: .mp4 and a key frame .png
    python3 tools/pixel-options.py picker HI         # HI/picker.json: the sets P1 to P5 and their motions, after the motions of S1
    # (the kit: quick by a play, kawa-quick then the pointer at 1672 216, the row hovered; notice by its scene, alone)
    python3 tools/pixel-options.py zoom PAGE X Y W H N OUT  # a part of a page, N times, nearest neighbour: to look at
"""
import json
import math
import pathlib
import subprocess
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


# the game-like rules of S4 (4 to 7): whole tiles of an odd pitch, their number chosen so the margins come out equal: every rule is its own mirror

def fit(n, pitch, tile, margin=0):
    """k tiles, tile wide, pitch apart, centred in n pixels with at least margin each side: (k, the first tile's offset)."""
    k = (n - 2 * margin - tile) // pitch + 1
    if (n - tile - (k - 1) * pitch) % 2:
        k -= 1
    return k, (n - tile - (k - 1) * pitch) // 2


def metal(mood):
    """Brass as P3's kanagu has it, on either ground: the dark's stands out by itself, on paper it goes a step down."""
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    if mood == "dark":
        return {"#": t["brass"], "h": t["brass_hi"], "l": t["brass_lo"], "r": t["accent"], "o": t["outline"]}
    return {"#": t["brass_lo"], "h": t["brass"], "l": t["tile"], "r": t["accent"], "o": t["outline"]}


STUD = ("..h..",
        ".h#l.",
        "h#r#l",
        ".#ll.",
        "..l..")
STOP = ("h.",
        "#h",
        "##",
        "#l",
        "l.")


def waku(page, mood, x0, x1, y):
    """A JRPG window's border laid flat: two rails, a brass stud every 17 px, a stepped stop at each end; the stud at the middle alone holds the red."""
    inks = metal(mood)
    plain = {**inks, "r": inks["#"]}
    n = x1 - x0 + 1
    for x in range(x0 + 2, x1 - 1):
        page.putpixel((x, y - 1), inks["h"])
        page.putpixel((x, y + 1), inks["l"])
    bitmap(page, x0, y - 2, STOP, inks)
    bitmap(page, x1 - 1, y - 2, [r[::-1] for r in STOP], inks)
    k, at = fit(n, 17, 5, 6)
    for i in range(k):
        heart = 2 * i - (k - 1) in (-1, 0, 1)
        bitmap(page, x0 + at + 17 * i, y - 2, STUD, inks if heart else plain)


RING = ("..hhh..",
        ".h...#.",
        "h.....l",
        ".#...l.",
        "..lll..")
EDGE = (".hhhh.",
        "#####l",
        ".llll.")


def kusari(page, mood, x0, x1, y):
    """A chain: a ring seen from the front, a link seen edge on, in turn, each through the last; pinned to the rule's two ends by a wire, drawn taut."""
    inks = metal(mood)
    k, at = fit(x1 - x0 + 1, 9, 7, 2)
    for x in list(range(x0, x0 + at + 1)) + list(range(x1 - at, x1 + 1)):
        page.putpixel((x, y), inks["#"])
    for i in range(k):
        bitmap(page, x0 + at + 9 * i, y - 2, RING, inks)
        if i < k - 1:
            bitmap(page, x0 + at + 9 * i + 5, y - 1, EDGE, inks)


def ken(page, mood, x0, x1, y, flip=False):
    """The rule is a sword: pommel, a corded hilt, the guard, the collar, then a blade of whatever length the rule has, its temper line a wave, the point stepped up."""
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    inks = metal(mood)
    spine, temper, edge = (t["ink"], t["brass_lo"], t["brass_hi"]) if mood == "dark" else (t["tile"], t["ink"], t["tile"])
    n = x1 - x0 + 1
    px = lambda i, d, c: page.putpixel((x1 - i if flip else x0 + i, y + d), c)
    for d in (-1, 0, 1):                                # the pommel
        px(0, d, inks["#"])
        px(1, d, inks["h" if d < 0 else "#"])
    for j, row in enumerate(("r.r.r.r.r.r.r.", ".#.#.#.#.#.#.#", "r.r.r.r.r.r.r.")):
        for i, c in enumerate(row):
            px(2 + i, j - 1, t["accent"] if c == "r" else inks["#"] if c == "#" else t["outline"])
    for d in range(-2, 3):                              # the guard
        px(16, d, inks["h"])
        px(17, d, inks["#"] if d < 2 else inks["l"])
    for d in (-1, 0, 1):                                # the collar
        for i in (18, 19, 20):
            px(i, d, inks["h" if d < 0 else "#"])
    point = n - 8
    for i in range(21, point):
        px(i, -1, spine)
        px(i, 0, edge if (i // 6) % 2 else temper)      # the temper line: a slow wave along the middle row
        px(i, 1, edge)
    for i, (top, foot) in zip(range(point, n), ((-1, 1), (-1, 1), (-1, 1), (-2, 0), (-2, 0), (-2, 0), (-2, -1), (-2, -2))):
        for d in range(top, foot + 1):                  # the point, rising to its tip
            px(i, d, spine if d == top else edge)


def kizami(page, mood, x0, x1, y):
    """A game's HUD, measured out: cells 5 by 3 with a lit top, every fifth from the middle a brass cell 5 rows tall, the red at the middle, a bracket at each end."""
    inks = metal(mood)
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    k, at = fit(x1 - x0 + 1, 7, 5, 4)
    for x, s in ((x0, 1), (x1, -1)):                    # the brackets
        for d in range(-2, 3):
            page.putpixel((x, y + d), inks["#"])
        page.putpixel((x + s, y - 2), inks["h"])
        page.putpixel((x + s, y + 2), inks["l"])
    for i in range(k):
        d = abs(2 * i - (k - 1))                        # from the middle, in half cells
        cx = x0 + at + 7 * i
        heart, major = d <= 1, d % 10 == (0 if k % 2 else 5)
        lit, body, foot = (t["accent_hi"], t["accent"], t["accent"]) if heart else (inks["h"], inks["#"], inks["l"]) if major else (t["ink"], t["ink"], t["edge2"])
        reach = 2 if heart or major else 1
        for x in range(cx, cx + 5):
            for r in range(-reach, reach + 1):
                page.putpixel((x, y + r), lit if r == -reach else foot if r == reach else body)


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
        elif n == 4:
            waku(page, mood, x0, x1, y)
        elif n == 5:
            kusari(page, mood, x0, x1, y)
        elif n == 6:
            ken(page, mood, x0, x1, y, flip)
        elif n == 7:
            kizami(page, mood, x0, x1, y)
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


def selected(page, mood):
    """The selected row of each list, Super+U's and quick settings' measured; the power menu's tile, the bar's tag and the notice's title from their shots."""
    rows = []
    for box, at in (SUPER_U, QUICK):
        w = box[2] - box[0], box[3] - box[1]
        rows.append(band(page, mood, (at[0], at[1], at[0] + w[0], at[1] + w[1])))
    tile = (POWER[1][0] + 38, POWER[1][1] + 20, POWER[1][0] + 102, POWER[1][1] + 84)
    tag = (64, 6, 98, 34)
    title = (NOTICE[1][0] + 16, NOTICE[1][1] + 120, NOTICE[1][0] + 76, NOTICE[1][1] + 140)
    return rows, tile, tag, title


def p2(page, mood, n, bob=0):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    rows, tile, tag, title = selected(page, mood)
    print(mood, "bands", [tuple(int(v) for v in r) for r in rows])
    words = [(rows[0][0] + 40, 56), (rows[1][0] + 33, 30)]   # (each band's label: its first column, its width)
    if n == 1:
        for x0, y0, _, y1 in rows:
            pointer(page, t, x0 - 11 + bob, (y0 + y1) // 2 - 4)     # (in the gutter, at the row's red edge: never on its icon)
        pointer(page, t, tile[0] + 28, tile[1] - 12 + bob, "down")
        pointer(page, t, tag[0] + 13, tag[3] + 2 - bob, "up")
        pointer(page, t, title[0] - 11 + bob, title[1] + 6)
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


def p4(page, mood, n, levels=(0.62, 0.15, 0.38)):
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
    left = round((1 - levels[2]) * 5)
    got = f"{round(levels[2] * 100)}% · {left} min" if left else "done"
    for k, (name, level, value) in enumerate((("volume", levels[0], f"{round(levels[0] * 100)}%"), ("battery", levels[1], f"{round(levels[1] * 100)}%"), ("downloads", levels[2], got))):
        top = y + 16 + 40 * k
        label(page, x + 16, top, name, text)
        label(page, x + 336, top, value, text, "rs")
        if name == "battery":                       # (low, by the same fire)
            f = dict(t, asagi=t["flame"], asagi_hi=t["flame_hi"], asagi_lo=t["flame_lo"])
            draw(page, f, x + 16, top + 21, level)
        elif name == "downloads":                   # (nearly done is no danger: no fire)
            f = dict(t, flame=t["asagi"], flame_hi=t["asagi_hi"], flame_lo=t["asagi_lo"])
            draw(page, f, x + 16, top + 21, level)
        else:
            draw(page, t, x + 16, top + 21, level)


# ---- P5, small accents

GLINT = ((),
         (".h.",
          "hoh",
          ".h."),
         ("..h..",
          "..o..",
          "hoooh",
          "..o..",
          "..h.."),
         ("...h...",
          "...h...",
          "...o...",
          "hhooohh",
          "...o...",
          "...h...",
          "...h..."))
PETAL = (("..hh.",
          ".hoo.",
          "ooos.",
          ".s..."),
         ("..hhh.",
          "ooooos",
          ".sss.."),
         (".hh..",
          ".ooh.",
          ".sooo",
          "...s."))
SWAY = (0, 1, 2, 1)                                 # the petal's poses, in turn: it tumbles


def glint(page, t, mood, x, y, size):
    """A sparkle on a thing's corner, centred on it: brass in the dark, the seal's red on paper, where brass doesn't show."""
    rows = GLINT[size]
    inks = {"h": t["brass_hi"], "o": t["brass"]} if mood == "dark" else {"h": t["accent_hi"], "o": t["accent"]}
    if size:
        bitmap(page, x - len(rows[0]) // 2, y - len(rows) // 2, rows, inks)


def petal(page, t, x, y, pose, ground, eaten=0):
    """A falling petal, behind whatever is written: only the window's own ground takes it."""
    for j, row in enumerate(PETAL[pose]):
        for i, c in enumerate(row):
            if c == "." or (x + y + i * 3 + j) % 4 < eaten:
                continue
            if max(abs(a - b) for a, b in zip(page.getpixel((x + i, y + j)), ground, strict=True)) <= 20:
                page.putpixel((x + i, y + j), {"h": t["accent_hi"], "o": t["accent"], "s": t["flame_lo"]}[c])


def p5(page, mood, n, phase=None):
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    if n == 1:                                      # mon: at the end of a title, where its rule starts; the rule steps aside
        at = []
        for x0, _, y in rules(page, mood, (20, 60, 725, 130)):
            for x in range(x0, x0 + 12):
                page.putpixel((x, y), page.getpixel((x, y - 2)))
            at.append((x0, y - 3))
        print(mood, "mon on the rule", at)
        for x, y in at + [(922, 85), (882, 187), (1675, 61)]:
            bitmap(page, x, y, CREST, {"#": t["accent"]})
    elif n == 2:                                    # kirari: on the corner of what has the focus
        rows, tile, tag, _ = selected(page, mood)
        size = 3 if phase is None else phase
        for _, y0, x1, _ in rows:
            glint(page, t, mood, int(x1), int(y0), size)
        glint(page, t, mood, tile[2], tile[1], size)
        glint(page, t, mood, tag[2] - 1, tag[1] - 2, size)   # (the tile's own corner)
    elif n == 3:                                    # hanabira: a petal or two, one come to rest on a window's rim
        ground = page.getpixel((700, 320))
        if phase is None:
            petal(page, t, 668, 262, 0, ground)
            petal(page, t, 596, 334, 1, ground)
            petal(page, t, 1140, 232, 2, page.getpixel((1180, 240)))
            petal(page, t, 1700, 186, 0, page.getpixel((1700, 196)))
        else:
            x, y, pose, eaten = phase
            petal(page, t, x, y, pose, ground, eaten)


# ---- all together: the favourite

def together(page, mood):
    """mon's rules, the pointer, the chest's fittings, the HP bar, a glint. (Not P5's crest: the rule has one.)"""
    p1(page, mood, 3)
    p4(page, mood, 1)
    t = {k: rgb(v) for k, v in TOKENS[mood].items()}
    metal = {"h": t["brass_hi"], "o": t["brass"], "s": t["brass_lo"], "#": t["outline"]}
    p3(page, mood, 3)
    x, y, w, h = LEVELS
    for c in corners((x, y, x + w - 1, y + h - 1)):
        stamp(page, c, KANAGU, metal)
    p2(page, mood, 1)
    p5(page, mood, 2)


def main(work, hi):
    for m in MOODS:
        for n in range(4):
            for name, fn in (("P1", p1), ("P2", p2), ("P3", p3), ("P4", p4), ("P5", p5)):
                page = base(work, hi, m)
                if n or name == "P4":
                    fn(page, m, n)
                save(page, pathlib.Path(hi) / f"{name}-{n}-{m}.png")
        page = base(work, hi, m)
        together(page, m)
        save(page, pathlib.Path(hi) / f"PA-{m}.png")


def games(work, hi):
    for m in MOODS:
        for n in range(4, 8):
            page = base(work, hi, m)
            p1(page, m, n)
            save(page, pathlib.Path(hi) / f"P1-{n}-{m}.png")


def save(page, out):
    page.save(out, optimize=True)
    print(out.name, page.size, out.stat().st_size)
    if out.stat().st_size > 3_000_000:
        sys.exit(f"{out}: over 3 MB")


# ---- what moves: drawn frame by frame, no screen; each a list of (a page's crop, how many frames at 60)

CROP_U = (8, 52, 648, 348)                          # Super+U, its list and its column
CROP_LEVELS = (784, 254, 1168, 428)                 # the mock-up of the levels


def ease(u):
    return 1 - (1 - min(u, 1.0)) ** 3


def clip(frames, crop, base_out, key):
    """frames: pages' crops at 2x, nearest neighbour, into BASE.mp4; frame KEY of them into BASE.png, 1:1."""
    w, h = (crop[2] - crop[0]) * 2, (crop[3] - crop[1]) * 2
    enc = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}", "-r", "60", "-i", "-",
                            "-vf", "scale=in_range=pc:out_range=tv,format=yuv420p", "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "14",
                            "-color_range", "tv", "-r", "60", "-movflags", "+faststart", str(base_out) + ".mp4"], stdin=subprocess.PIPE)
    count = 0
    for page, hold in frames:
        im = page.crop(crop)
        if count <= key < count + hold:
            im.save(str(base_out) + ".png", optimize=True)
        raw = im.resize((w, h), Image.NEAREST).tobytes()
        for _ in range(hold):
            enc.stdin.write(raw)
        count += hold
    enc.stdin.close()
    if enc.wait():
        sys.exit(f"{base_out}: ffmpeg failed")
    print(pathlib.Path(str(base_out) + ".mp4").name, count, "frames", pathlib.Path(str(base_out) + ".mp4").stat().st_size)


def motions(work, hi):
    hi = pathlib.Path(hi)
    for m in MOODS:
        ground = base(work, hi, m)
        frames = []
        for k in range(27):                         # a pose held 9 frames (150 ms), whole pixels, out and back; 4 seconds
            page = ground.copy()
            p2(page, m, 1, (0, 1, 2, 1)[k % 4])
            frames.append((page, 9))
        clip(frames, CROP_U, hi / f"P2m-1-{m}", 0)
        for n in range(4):
            ground = base(work, hi, m)
            frames = []
            for f in range(270):                    # up to the top, into the fire, back to its level; the download steady; 4.5 s
                s = f / 60
                vol = ease(s / 1.5) if s < 1.5 else 1.0 if s < 1.9 else 1 - 0.38 * ease((s - 1.9) / 0.7)
                page = ground.copy()
                p4(page, m, n, (vol, 0.15, min(s / 3.4, 1.0)))
                frames.append((page, 1))
            clip(frames, CROP_LEVELS, hi / f"P4m-{n}-{m}", 75)
        ground = base(work, hi, m)
        frames = []
        for size, hold in ((1, 4), (2, 4), (3, 6), (2, 4), (1, 4), (0, 138)) * 2:   # a glint, 22 frames, then rest; 4 seconds
            page = ground.copy()
            p5(page, m, 2, size)
            frames.append((page, hold))
        clip(frames, CROP_U, hi / f"P5m-2-{m}", 8)
        frames = []
        for f in range(330):                        # down at 55 px a second, swaying, tumbling; a rest on the rim; dissolving
            page = ground.copy()
            y = min(112 + f * 55 // 60, 334)
            x = 628 + round(9 * math.sin(f / 22))
            eaten = max(0, (f - 290) // 10)
            done = y >= 334
            p5(page, m, 3, (x if not done else 628 + round(9 * math.sin(241 / 22)), y, 1 if done else SWAY[f // 12 % 4], eaten))
            frames.append((page, 1))
        clip(frames, CROP_U, hi / f"P5m-3-{m}", 130)


def picker(hi):
    path = pathlib.Path(hi) / "picker.json"
    old = [e for e in json.loads(path.read_text()) if not e["set"].startswith("P")]
    def still(st, title, provisional, names, note):
        return {"set": st, "title": title, "kind": "still", "provisional": provisional, "moods": list(MOODS),
                "options": [{"n": n, "name": name, "text": text, "files": [f"{st}-{n}-{m}.png" for m in MOODS]} for n, (name, text) in enumerate(names)], "note": note}
    def moving(st, title, provisional, names, note):
        return {"set": st, "title": title, "kind": "motion", "provisional": provisional, "moods": list(MOODS),
                "options": [{"n": n, "name": name, "text": text, "files": [f"{st}-{n}-{m}.{e}" for m in MOODS for e in ("mp4", "png")]} for n, name, text in names], "note": note}
    pages = "1:1 on the real screens (Super+U, quick settings, the power menu, notices, the bar), nothing applied yet."
    new = [
        still("P1", "Rules and separators", 3, (("today", "a plain line"), ("kasumi", "dithered mist"), ("nami", "a band of seigaiha"), ("mon", "stepped caps, a crest")), pages),
        still("P2", "The selection marker", 1, (("today", "the band and its red edge"), ("yubi", "a JRPG pointer in the gutter"), ("fude", "a brush stroke under the label"), ("kagi", "corner brackets")), pages),
        moving("P2m", "The pointer bobbing", 1, ((1, "yubi", "whole pixels, 150 ms a pose"),), "Super+U at 2x, the png 1:1. The other markers stand still."),
        still("P3", "Corners and frames", 3, (("today", "a plain frame"), ("kakko", "quotation brackets"), ("kaidan", "a dialog box's stairs"), ("kanagu", "a chest's brass fittings")), pages + " The power menu keeps its rods."),
        still("P4", "Meters", 1, (("today", "40 segments"), ("tairyoku", "an HP bar"), ("hishi", "20 lozenges on a cord"), ("katana", "the blade the scale")), pages + " Volume, battery and downloads are a mock-up panel: the shots hold none of them."),
        moving("P4m", "The meters filling", 1, ((0, "today", "40 segments"), (1, "tairyoku", "an HP bar"), (2, "hishi", "20 lozenges"), (3, "katana", "the blade")), "The mock-up panel at 2x, the png 1:1. Volume runs into the fire and back."),
        still("P5", "Small accents", 2, (("today", "none"), ("mon", "a crest ending a title"), ("kirari", "a sparkle on the focus"), ("hanabira", "a falling petal")), pages),
        moving("P5m", "The accents that move", 2, ((2, "kirari", "a glint every 2 seconds"), (3, "hanabira", "falls behind the words, rests, dissolves")), "Super+U at 2x, the png 1:1."),
        {"set": "PA", "title": "All together", "kind": "still", "provisional": 1, "moods": list(MOODS),
         "options": [{"n": 1, "name": "the favourite", "text": "mon, yubi, kanagu, tairyoku, kirari", "files": [f"PA-{m}.png" for m in MOODS]}], "note": pages + " A provisional number here is only the favourite."},
    ]
    at = next(i for i, e in enumerate(old) if e["kind"] != "motion")
    path.write_text(json.dumps(old[:at] + new + old[at:], ensure_ascii=False, indent=1) + "\n")


def zoom(src, x, y, w, h, n, out):
    x, y, w, h, n = int(x), int(y), int(w), int(h), int(n)
    Image.open(src).convert("RGB").crop((x, y, x + w, y + h)).resize((w * n, h * n), Image.NEAREST).save(out)


if __name__ == "__main__":
    if sys.argv[1] == "zoom":
        zoom(*sys.argv[2:])
    elif sys.argv[1] == "games":
        games(*sys.argv[2:])
    elif sys.argv[1] == "motions":
        motions(*sys.argv[2:])
    elif sys.argv[1] == "picker":
        picker(*sys.argv[2:])
    else:
        main(*sys.argv[1:])
