#!/usr/bin/env python3
"""tests/menus/cols.py [--px] — how wide each line on stdin is in a menu, one number a line:
in 6 px columns (a part column counting whole), or with --px in pixels, as fuzzel lays it out
in the desktop's fonts. Fusion Pixel's letters are 6 px, and 12 px where art/fusion-wide.txt says
(─ … → and the like) or, from U+3000 on, where East Asian width says so; the Sumi Icons
(plane 15) are as wide as art/icons.txt makes them (14 px for most); combining marks and
joiners take nothing. (Arabic, in Noto Kufi, is narrower than a column a letter: counted as
one, it errs on the safe side.)"""
import pathlib
import re
import sys
import unicodedata

HERE = pathlib.Path(__file__).resolve().parent
COL = 6


def wide_table():
    spans = []
    for line in (HERE.parent.parent / "art/fusion-wide.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            continue
        for item in line.split():
            a, _, b = item.partition("-")
            spans.append((int(a, 16), int(b or a, 16)))
    return spans


def icon_advances():
    """U+FE000 onwards, in art/icons.txt's order: each icon's advance (adv=, else width + 4)."""
    adv, cur = [], None
    for line in (HERE.parent.parent / "art/icons.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("@"):
            if cur:
                adv.append(cur["adv"] if cur["adv"] is not None else cur["w"] + 4)
            m = re.search(r"\badv=(-?\d+)", line)
            cur = {"adv": int(m.group(1)) if m else None, "w": 0}
        elif cur and line and set(line) <= {"#", "."}:
            cur["w"] = max(cur["w"], len(line))
    if cur:
        adv.append(cur["adv"] if cur["adv"] is not None else cur["w"] + 4)
    return adv


WIDE = wide_table()
ICONS = icon_advances()


def px(c):
    o = ord(c)
    if 0xFE000 <= o < 0xFE000 + len(ICONS):
        return ICONS[o - 0xFE000]
    if 0xF0000 <= o <= 0xFFFFD:
        return 2 * COL
    if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0
    if o < 0x3000:
        return 2 * COL if any(a <= o <= b for a, b in WIDE) else COL
    return 2 * COL if unicodedata.east_asian_width(c) in ("W", "F") else COL


def cols(s):
    return -(-sum(px(c) for c in s) // COL)


if __name__ == "__main__":
    measure = (lambda s: sum(px(c) for c in s)) if sys.argv[1:] == ["--px"] else cols
    for line in sys.stdin.buffer.read().decode("utf-8", "replace").split("\n")[:-1]:
        print(measure(line))
