#!/usr/bin/env python3
"""tools/apps-review-measure.py SHOTS OUT — tools/apps-review.sh's sheets and tables: each surface cut to its frame from
SHOTS/{dark,light}/NAME.png, dark | light at 1× (NN-name.png), a part at 4× (NN-name-4x.png), and what it measures beside them
(NN-name.md: the note on his page). Every number is read from the pixels of the shot, the dark one's and the light one's; a line
says ≠ if the two moods differ (a theme is inks, never geometry)."""
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image

shots, out = sys.argv[1:3]


def load(mood, name):
    return np.asarray(Image.open(os.path.join(shots, mood, name + ".png")).convert("RGB"), dtype=np.int16)


def frame_box(a):
    """The floating window's box: its accent hairline's outer rectangle, under the bar (a light shadow's rows left out)."""
    h, w, _ = a.shape
    g = a[h - 3, 3]                                    # (the ground)
    d = np.abs(a - g).sum(axis=2) > 24
    d[:30, :] = False
    ys, xs = np.nonzero(d)
    x0, y0 = int(xs.min()), int(ys.min())
    ink = a[y0, (x0 + int(xs.max())) // 2]             # (the hairline's colour: the top one's, the frame's)
    same = np.abs(a - ink).sum(axis=2) < 12
    x1 = max(x for x in range(x0, w) if same[y0 + 4:int(ys.max()) - 4, x].mean() > 0.8) + 1
    y1 = max(y for y in range(y0, h) if same[y, x0 + 4:x1 - 4].mean() > 0.8) + 1
    return x0, y0, x1, y1


def ink_box(a, region, ground=None, tol=30):
    x0, y0, x1, y1 = region
    r = a[y0:y1, x0:x1]
    g = ground if ground is not None else r[0, 0]
    d = np.abs(r - g).sum(axis=2) > tol
    ys, xs = np.nonzero(d)
    if not len(xs):
        return None
    return x0 + int(xs.min()), y0 + int(ys.min()), x0 + int(xs.max()) + 1, y0 + int(ys.max()) + 1


def sheet(name, nn, shot=None, note=(), zoom=None, box=None):
    """NN-name.png: the two moods side by side, each cut to box or its frame; NN-name-4x.png: the region zoom = (x, y, w, h) inside
    that cut, the two moods one over the other."""
    shot = shot or name
    parts, cuts = [], []
    for mood in ("dark", "light"):
        im = Image.open(os.path.join(shots, mood, shot + ".png")).convert("RGB")
        b = box or frame_box(np.asarray(im, dtype=np.int16))
        b = (max(0, b[0] - 8), max(0, b[1] - 8), min(im.width, b[2] + 8), min(im.height, b[3] + 8))
        parts.append(im.crop(b))
        cuts.append(b)
    gap = 12
    w = sum(p.width for p in parts) + gap
    h = max(p.height for p in parts)
    if w > 1920:                                       # (a full-screen surface: one over the other)
        w, h = max(p.width for p in parts), sum(p.height for p in parts) + gap
        s = Image.new("RGB", (w, h), (90, 90, 90))
        s.paste(parts[0], (0, 0))
        s.paste(parts[1], (0, parts[0].height + gap))
    else:
        s = Image.new("RGB", (w, h), (90, 90, 90))
        s.paste(parts[0], (0, 0))
        s.paste(parts[1], (parts[0].width + gap, 0))
    s.save(os.path.join(out, f"{nn}-{name}.png"))
    if zoom:
        x, y, zw, zh = zoom
        z = Image.new("RGB", (zw * 4, zh * 8 + gap), (90, 90, 90))
        for i, p in enumerate(parts):
            c = p.crop((x, y, x + zw, y + zh)).resize((zw * 4, zh * 4), Image.NEAREST)
            z.paste(c, (0, i * (zh * 4 + gap)))
        z.save(os.path.join(out, f"{nn}-{name}-4x.png"))
    with open(os.path.join(out, f"{nn}-{name}.md"), "w") as f:
        f.write("\n".join(note) + "\n")


PX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "px.py")


def px(mood, shot, *args):
    """tools/px.py on a shot, its JSON answer."""
    out = subprocess.run([sys.executable, PX, args[0], os.path.join(shots, mood, shot + ".png"), *args[1:], "--json"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def spans(shot, axis, region):
    """The ink's spans along an axis of a region, as "from+len" in screen pixels: one mood's, or both if they differ."""
    x, y, w, h = region
    res = []
    for mood in ("dark", "light"):
        r = px(mood, shot, "gaps", axis, "--region", f"{x},{y},{w},{h}")
        res.append(" · ".join(f"{a}+{n}" for a, n in r["spans"]))
    return res[0] if res[0] == res[1] else f"{res[0]} ≠ light {res[1]}"


def table(rows):
    return ["", "| measured with tools/px.py (from+length, screen px) | |", "|---|---|"] + [f"| {a} | {b} |" for a, b in rows]


# ── books ─────────────────────────────────────────────────────────────────────────────
def books_cover(a):
    x0, y0, x1, y1 = frame_box(a)                      # the window's hairlines
    g = a[y0 + 3, (x0 + x1) // 2]                      # (the window's ground)
    d = np.abs(a - g).sum(axis=2) > 3
    # the pane's rule: the column in the right half with ink on (nearly) every row of its middle
    mid = d[y0 + 60:y1 - 60]
    rule = next(x for x in range((x0 + x1) // 2, x1 - 2) if mid[:, x].mean() > 0.98)
    # the cover: the ink right of the rule, its rows the widest ones (the words under it are narrower)
    pane = d[y0 + 2:y1 - 2, rule + 2:x1 - 2]
    widths = pane.sum(axis=1)
    rows = np.nonzero(widths > 0.8 * widths.max())[0]
    cols = np.nonzero(pane[rows].mean(axis=0) > 0.5)[0]
    cl, cr = cols.min() + rule + 2, cols.max() + rule + 3
    # the block: the cover and the words: all the ink in the pane
    all_rows = np.nonzero(pane.any(axis=1))[0]
    top, bot = all_rows.min() + y0 + 2, all_rows.max() + y0 + 3
    return (int(cl - rule - 1), int(x1 - 1 - cr), int(top - y0 - 1), int(y1 - 1 - bot), int(cr - cl))


cl, cr, ct, cb, cw = books_cover(load("dark", "books"))
cl2, cr2, ct2, cb2, cw2 = books_cover(load("light", "books"))
sheet("books", "40", note=[
    "Super+R: the cover centred both ways, the words centred under it; \"new\" only beside a book begun; the cursor a thin bar, before the ghost's first letter.",
    "",
    "| measured (dark · light) | px |",
    "|---|---|",
    f"| rule → cover · cover → hairline | {cl} · {cr} (light {cl2} · {cr2}) |",
    f"| window's top → block · block → window's foot | {ct} · {cb} (light {ct2} · {cb2}) |",
    f"| the cover's width | {cw} (light {cw2}) |",
    "",
    "Judge: is the cover where it should be? A row's value now stands as far in from the band's end as its icon from the start.",
], zoom=(0, 0, 380, 160))

# ── the wallpaper picker ──────────────────────────────────────────────────────────────
sheet("wallpaper-picker", "41", shot="wall", note=[
    "Super+W: the settings under the list, as options: every value in sight, the chosen one's dot, each key's tile at the row's end (r, o, s; a click on the row too). The list by its sections, the old masters second, a label the cursor passes by. The picture centred between the settings and the window's hairline.",
    "",
    "change by itself: off · 1 h · 4 h · daily (a look every hour, the time running from the last change, a pick of yours too). order: in turn · shuffle. from: old masters · scenes · both.",
    "",
    "Judge: do the three rows read as options now?",
] + table([
    ("heading's row, across", spans("wall", "x", (640, 203, 640, 20))),
    ("a label's row, across (its rule, its count)", spans("wall", "x", (640, 243, 640, 20))),
    ("a picture's row, across (icon, name, value)", spans("wall", "x", (640, 263, 640, 20))),
    ("the settings, down (three rows on the 20 px pitch)", spans("wall", "y", (680, 500, 130, 62))),
    ("the settings' first row, across (icon, label, dots and words, the tile)", spans("wall", "x", (640, 503, 640, 20))),
    ("the settings' third row, across", spans("wall", "x", (640, 543, 640, 20))),
    ("the picture, across · down", spans("wall", "x", (640, 700, 640, 20)) + " — " + spans("wall", "y", (900, 563, 20, 366))),
]), zoom=(10, 310, 680, 120))
sheet("wallpaper-picker-set", "42", shot="wall-set", note=["The same, each setting moved once: the dots stand one over the other, row to row."])

# ── the calculator ────────────────────────────────────────────────────────────────────
for nn, n, t in (("43", "calc-empty", "As it opens: what it can do, faint, until there is a sum."),
                 ("44", "calc-typed", "A sum typed: the answer at twice the size (§2's display size), its units small and muted on its baseline, what Enter does as a key."),
                 ("45", "calc-copied", "Enter: copied, said in place, no notice; the sum kept below, a clean line."),
                 ("46", "calc-row", "The cursor down on the session's sums: Enter copies one.")):
    extra = [] if n != "calc-typed" else table([
        ("the panel, down (heading, line, answer, rows, keys)", spans(n, "y", (775, 410, 40, 260))),
        ("heading's row, across", spans(n, "x", (760, 425, 400, 16))),
        ("the answer's row, across (figures, unit, tile, word)", spans(n, "x", (760, 490, 400, 34))),
        ("a hint's row, across", spans(n, "x", (760, 534, 400, 18))),
        ("the keys' row, across", spans(n, "x", (760, 640, 400, 18))),
    ])
    sheet(n, nn, note=["The calculator, a floating panel as the launcher (kawa-panel), never a whole screen. " + t] + extra,
          zoom=(0, 0, 430, 150) if n == "calc-typed" else None)

# ── btop ──────────────────────────────────────────────────────────────────────────────
sheet("btop", "47", note=[
    "btop: fewer boxes (processor, card, memory, processes; the network one key away, 3); every core's same heat gone; memory as graphs that fill the box; one ramp for what rises (asagi → gold → the seal's red), one calm ink for what is good to have; its rules' words stepped back, so the numbers and the graphs are what you see.",
    "",
    "A fresh btop's graphs fill from the right, a sample a second. Its words in the rules (menu, preset, filter, pause …) are in its C++: a source patch could take them out; there is no C++ compiler on this PC without an install (a question for the main run, in the lane's notes).",
])

# ── yazi ──────────────────────────────────────────────────────────────────────────────
FULL = (0, 28, 1920, 1080)
sheet("yazi", "48", shot="y-folder", box=FULL, note=[
    "Super+E: a breadcrumb (the folders above muted, the one you are in strong); size and age in columns, numbers muted, units faint; dotfiles muted; the preview always shows something (a folder's rows: it stood empty because of a bug); footer: size · changed · permissions · place.",
] + table([
    ("the heading's row, across", spans("y-folder", "x", (20, 43, 1890, 20))),
    ("the cursor's row, across the list (its edge, icon, name, size, age)", spans("y-folder", "x", (262, 122, 690, 20))),
    ("a file's row, across the list", spans("y-folder", "x", (262, 402, 690, 20))),
    ("the list, down (the 20 px pitch)", spans("y-folder", "y", (300, 80, 40, 240))),
    ("the footer, across", spans("y-folder", "x", (20, 1043, 1890, 20))),
]), zoom=(260, 40, 700, 200))
sheet("yazi-card", "49", shot="y-card", box=FULL, note=["What has no picture: a card of its facts in the preview, never an empty pane."])
for nn, n, sh, t in (("50", "yazi-rename", "y-rename", "Rename: the panel's own frame in the terminal's cells (no rounded corner, nothing in its rule), its heading; the field lies exactly over the name it renames."),
                     ("51", "yazi-trash", "y-trash", "Trash: the panel fits what it says, the folder once, the names, the choices as key tiles."),
                     ("52", "yazi-create", "y-create", "New file: what is typed shows the icon of what it will be."),
                     ("53", "yazi-help", "y-help", "Help (~): keys as tiles, a search line with a ghost and a count, what they do in plain lower case."),
                     ("54", "yazi-which", "y-which", "A prefix key (g): the strip of what follows, each key its tile."),
                     ("55", "yazi-tasks", "y-tasks", "Tasks (w): the frame, its heading; none said quietly."),
                     ("56", "yazi-open", "y-pick", "Open with (o).")):
    extra = []
    if n in ("yazi-trash", "yazi-rename"):
        d = load("dark", sh)
        ink = np.array((0x80, 0x73, 0x5b), dtype=np.int16)       # (foot's slot 33: the hairline of what floats, dark)
        hit = np.abs(d - ink).sum(axis=2) < 6
        rows = [y for y in range(30, 1070) if hit[y].sum() > 200]
        cols = [x for x in range(10, 1910) if hit[:, x].sum() > 50]
        if rows and cols:
            x0, x1, y0, y1 = cols[0], cols[-1], rows[0], rows[-1]
            ic = spans(sh, "x", (x0 + 1, y0 + 1, x1 - x0 - 1, 40))
            dn = spans(sh, "y", (x0 + 1, y0 + 1, 60, y1 - y0 - 1))
            extra = table([("the ring: left, right hairlines · top, bottom", f"x {x0}, {x1} · y {y0}, {y1}"),
                           ("under the top hairline, across (the heading: icon, name, rule)", ic),
                           ("inside the ring, down", dn)])
    sheet(n, nn, shot=sh, box=FULL, note=[t] + extra)
sheet("yazi-half", "57", shot="y-half", note=["Half a screen: the size stays, the age goes when the list is narrower than 52 columns."])
sheet("yazi-third", "58", shot="y-third", note=["The spiral's third window: the list and the preview, nothing cut, the footer on one line."])
print(f"apps-review: → {out}")
