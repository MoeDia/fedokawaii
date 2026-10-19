#!/usr/bin/env python3
"""tests/menus/fits.py WIDTH TITLE < rows — does every line of a panel menu (kawa-panel --menu's
line format) fit whole, as the panel lays it out? Nothing is ever cut with "…" there, so a
line too wide is a fault. Prints one complaint per line that does not fit (nothing: all fit).
The content is 6 × WIDTH + 12 (120 at least) with a --width, else as wide as the screen allows
(1876 px: the menu sizes itself to its content); a row: 6 px, its 12 px glyph, 6 px, the name
(the details' column after the longest name of a row with one, 12 px on), 12 px before a
value, 6 px at the end; a heading: the 23 px seal, 6, the name, 6, at least 12 px of stitch,
6 and its value; keys sharing a row: equal, 6 px apart, their glyph, 6 and name with 6 px
inside each end; a note (the title too): 6 px in, 6 px from the end; a cell: 36 px."""
import pathlib
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import cols  # noqa: E402

width = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
title = sys.argv[2] if len(sys.argv) > 2 else ""
# (sized to its content: a menu with no --width is as wide as its widest line, so it must fit
# the screen — 1920 px less 8 px each side, its frame and pad: 1876 px of content)
W = max(120, 6 * width + 12) if width else 1876
rows = sys.stdin.read().split("\n")
if rows and rows[-1] == "":
    rows.pop()


def px(t):
    return sum(cols.px(c) for c in t)


def f(line):
    parts = line.split("\t")
    return parts + [""] * (5 - len(parts))


KINDS = ("part", "row", "on", "off", "key", "cell", "note")
lines = [(i, f(l)) for i, l in enumerate(rows) if l.strip()]
named = [px(x[2]) for _, x in lines if x[0] in ("row", "on", "off") and x[3]]
dx = 24 + (max(named) if named else 0) + 12
bad = []
if title and 6 + px(title) > W - 6:
    bad.append(f"title [{title}] {6 + px(title)} px > {W - 6}")
k = 0
while k < len(lines):
    i, x = lines[k]
    kind = x[0] if x[0] in KINDS and "\t" in rows[i] else "plain"
    if kind == "part":
        need = 23 + 6 + px(x[2]) + 6 + 12 + ((6 + px(x[3])) if x[3] else 0)
    elif kind in ("row", "on", "off"):
        tail = (12 + px(x[4])) if x[4] else 0
        need = (dx + px(x[3]) if x[3] else 24 + px(x[2])) + tail + 6
    elif kind == "key":
        run = [lines[k]]
        while k + 1 < len(lines) and lines[k + 1][1][0] == "key":
            k += 1
            run.append(lines[k])
        kw = (W - (len(run) - 1) * 6) // len(run)
        for j, y in run:
            n = 12 + ((12 + 6) if y[1] else 0) + px(y[2])
            if n > kw:
                bad.append(f"line {j} [{rows[j]}] {n} px > its key's {kw}")
        k += 1
        continue
    elif kind == "cell":
        need = px(x[1]) * W // 36 if px(x[1]) > 36 else 0
    elif kind == "note":
        need = 6 + px(x[1]) + 6
    else:
        need = 24 + px(rows[i]) + 6
    if need > W:
        bad.append(f"line {i} [{rows[i]}] {need} px > {W}")
    k += 1
print(" | ".join(bad))
