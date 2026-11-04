#!/usr/bin/env python3
"""tools/regress/term-grid.py KNOWN COLS_DIR OUT THEME… — what tools/regress/term-grid.sh's shots show.

For each OUT/THEME/NAME.txt and NAME.png: no line wider than the window, no "…" on a screen of ours, no
error on the screen, not blank; its heading whole; its right edges on one column; the window its size,
nothing drawn into its pad. A finding whose
"THEME NAME: what" matches a line of KNOWN (fnmatch, then its reason after " # ") is only counted.
Exit 0 · 1 a finding not known · 2 nothing to read."""
import fnmatch
import glob
import os
import re
import sys
import unicodedata

import numpy as np
from PIL import Image

CELL_W, CELL_H, PAD = 8, 20, 8
# screens of ours: the rule "never truncate with …" is theirs to keep; others draw their own
OURS = {"prompt", "git", "calc", "clip", "books", "wallpaper", "system", "yazi", "wide"}
# each screen's heading, whole wherever it has the room (cut at a word or fit: never "bo" for "books")
HEADINGS = {"git": "repositories", "calc": "calculator", "clip": "clipboard", "books": "books", "wallpaper": "wallpaper",
            "system": "status"}
ERRORS = re.compile(r"Traceback|command not found|No such file or directory|syntax error|: line \d+:|Permission denied|unbound variable")


def width(line):
    """Columns as foot counts them: W and F two, combining marks and joiners none."""
    n = 0
    for c in line:
        if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
            continue
        n += 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
    return n


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)


def window_box(a, base):
    """The window's outer box: the first and last rows and columns that are not the empty screen."""
    moved = np.any(a[27:] != base[27:], axis=-1)
    ys, xs = np.nonzero(moved)
    if not len(ys):
        return None
    return int(xs.min()), int(ys.min()) + 27, int(xs.max()), int(ys.max()) + 27


def judge(name, a, base, text):
    """A screen's findings. NAME is PROGRAM-COLSxROWS, or a scene's own name."""
    out = []
    prog = name.split("-")[0].split(":")[-1]      # (prompt-80x24 → prompt, zoom+2:yazi → yazi)
    m = re.search(r"-(\d+)x(\d+)$", name)
    cols, rows = (int(m.group(1)), int(m.group(2))) if m else (None, None)
    if text is None:
        out.append("no words read (the window was gone)")
        return out
    if not text.strip():
        out.append("a blank screen")
    if prog in OURS and "…" in text:
        out.append("an ellipsis on the screen")
    e = ERRORS.search(text)
    if e:
        out.append(f"an error on the screen: {e.group(0)}")
    if cols and not name.startswith(("zoom",)):
        wide = max((width(ln) for ln in text.split("\n")), default=0)
        if wide > cols:
            out.append(f"a line {wide} wide in a window of {cols}")
    head = HEADINGS.get(prog)
    if head and cols and cols >= len(head) + 8 and head not in text:
        out.append(f"the heading cut: no \"{head}\" whole")
    # the right edge: the heading's rule, the counter and the footer's end on one column (§7)
    rows_ = [ln.rstrip() for ln in text.split("\n") if ln.strip()]
    if prog in ("git", "clip", "wide", "yazi") and cols and rows_ and cols >= 30:
        rule = next((ln for ln in rows_ if ln.endswith("─")), None)
        count = next((ln for ln in rows_ if re.search(r"\d+/\d+$", ln)), None)
        if rule and count and width(rule) != width(count):
            out.append(f"the right edges differ: the rule ends at {width(rule)}, the count at {width(count)}")
    box = window_box(a, base)
    if box is None:
        out.append("no window on the screen")
        return out
    x0, y0, x1, y1 = box
    if cols:
        # the frame: 1 px hairline; the shadow's column at the right and two rows under it
        w, h = x1 - x0 + 1, y1 - y0 + 1
        want_w, want_h = cols * CELL_W + 2 * PAD + 3, rows * CELL_H + 2 * PAD + 4
        if abs(w - want_w) > 2 or abs(h - want_h) > 2:
            out.append(f"the window {w} × {h}, not {want_w} × {want_h}")
        # its pad: 8 px inside the hairline, one colour all round: nothing in it
        ix0, iy0, ix1, iy1 = x0 + 1, y0 + 1, x0 + 1 + 2 * PAD + cols * CELL_W - 1, y0 + 1 + 2 * PAD + rows * CELL_H - 1
        strips = [a[iy0:iy0 + PAD, ix0:ix1 + 1], a[iy1 - PAD + 1:iy1 + 1, ix0:ix1 + 1], a[iy0:iy1 + 1, ix0:ix0 + PAD], a[iy0:iy1 + 1, ix1 - PAD + 1:ix1 + 1]]
        ground = a[iy0 + 2, ix0 + 2]
        drawn = sum(int(np.any(s != ground, axis=-1).sum()) for s in strips)
        if drawn:
            out.append(f"{drawn} px drawn into the window's pad")
    return out


def main(argv):
    if len(argv) < 5:
        print(__doc__)
        return 2
    known = []
    with open(argv[1], encoding="utf8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                pat, _, why = line.partition(" # ")
                known.append((pat.strip(), why.strip()))
    out, themes = argv[3], argv[4:]
    new, seen, screens = [], {}, 0
    for th in themes:
        d = os.path.join(out, th)
        base = load(os.path.join(d, "base.png"))
        for png in sorted(glob.glob(os.path.join(d, "*.png"))):
            name = os.path.basename(png)[:-4]
            if name in ("base", "stream"):
                continue
            screens += 1
            a = load(png)
            txt = png[:-4] + ".txt"
            text = open(txt, encoding="utf8", errors="replace").read() if os.path.exists(txt) else None
            for f in judge(name, a, base, text):
                line = f"{th} {name}: {f}"
                hit = next((k for k in known if fnmatch.fnmatchcase(line, k[0])), None)
                if hit:
                    seen.setdefault(hit[0], []).append(line)
                else:
                    new.append(line)
        log = os.path.join(d, "play.log")
        said = open(log, encoding="utf8").read() if os.path.exists(log) else ""
        if "stream dead" in said:
            new.append(f"{th} stream: the window under a live resize died")
    if not screens:
        print("term-grid: no screen to read")
        return 2
    for line in new:
        print(f"term-grid: {line}")
    stale = [k[0] for k in known if k[0] not in seen]
    tail = f"; {sum(map(len, seen.values()))} known ({len(seen)} kinds)" if seen else ""
    tail += f"; {len(stale)} known no longer seen: {stale[0]} …" if stale else ""
    print(f"term-grid: {'BROKEN' if new else 'held'} — {screens} screens, both themes{tail}" if len(themes) == 2 else f"term-grid: {'BROKEN' if new else 'held'} — {screens} screens{tail}")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
