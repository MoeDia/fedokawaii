#!/usr/bin/env python3
"""tools/apps-review-measure.py SHOTS OUT — tools/apps-review.sh's sheets and tables: each surface cut to its frame from
SHOTS/{dark,light}/NAME.png, dark | light at 1× (NN-name.png), a part at 4× (NN-name-4x.png), and what it measures beside them
(NN-name.md: the note on his page). Every number is read from the pixels of the shot, the dark one's and the light one's; a line
says ≠ if the two moods differ (a theme is inks, never geometry)."""
import os
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


def both(fn):
    """fn(array) in each mood: its value, or both if they differ."""
    d, l = fn(load("dark", both.shot)), fn(load("light", both.shot))
    return f"{d}" if d == l else f"{d} ≠ {l} (light)"


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


both.shot = "books"
l, r, t, b, w = books_cover(load("dark", "books"))
l2, r2, t2, b2, w2 = books_cover(load("light", "books"))
sheet("books", "40", note=[
    "Super+R: the cover centred both ways, the words centred under it; \"new\" only beside a book begun; the cursor a thin bar, before the ghost's first letter.",
    "",
    "| measured (dark · light) | px |",
    "|---|---|",
    f"| rule → cover · cover → hairline | {l} · {r} (light {l2} · {r2}) |",
    f"| window's top → block · block → window's foot | {t} · {b} (light {t2} · {b2}) |",
    f"| the cover's width | {w} (light {w2}) |",
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
], zoom=(10, 310, 680, 120))
sheet("wallpaper-picker-set", "42", shot="wall-set", note=["The same, each setting moved once: the dots stand one over the other, row to row."])

# ── the calculator ────────────────────────────────────────────────────────────────────
for nn, n, t in (("43", "calc-empty", "As it opens: what it can do, faint, until there is a sum."),
                 ("44", "calc-typed", "A sum typed: the answer at twice the size (§2's display size), its units small and muted on its baseline, what Enter does as a key."),
                 ("45", "calc-copied", "Enter: copied, said in place, no notice; the sum kept below, a clean line."),
                 ("46", "calc-row", "The cursor down on the session's sums: Enter copies one.")):
    sheet(n, nn, note=["The calculator, a floating panel as the launcher (kawa-panel), never a whole screen. " + t],
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
], zoom=(260, 40, 700, 200))
sheet("yazi-card", "49", shot="y-card", box=FULL, note=["What has no picture: a card of its facts in the preview, never an empty pane."])
for nn, n, sh, t in (("50", "yazi-rename", "y-rename", "Rename: the panel's own frame in the terminal's cells (no rounded corner, nothing in its rule), its heading; the field lies exactly over the name it renames."),
                     ("51", "yazi-trash", "y-trash", "Trash: the panel fits what it says, the folder once, the names, the choices as key tiles."),
                     ("52", "yazi-create", "y-create", "New file: what is typed shows the icon of what it will be."),
                     ("53", "yazi-help", "y-help", "Help (~): keys as tiles, a search line with a ghost and a count, what they do in plain lower case."),
                     ("54", "yazi-which", "y-which", "A prefix key (g): the strip of what follows, each key its tile."),
                     ("55", "yazi-tasks", "y-tasks", "Tasks (w): the frame, its heading; none said quietly."),
                     ("56", "yazi-open", "y-pick", "Open with (o).")):
    sheet(n, nn, shot=sh, box=FULL, note=[t])
sheet("yazi-half", "57", shot="y-half", note=["Half a screen: the size stays, the age goes when the list is narrower than 52 columns."])
sheet("yazi-third", "58", shot="y-third", note=["The spiral's third window: the list and the preview, nothing cut, the footer on one line."])
print(f"apps-review: → {out}")
