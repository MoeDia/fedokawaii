#!/usr/bin/env python3
"""tests/menus/cols.py [--px] — how wide each line on stdin is in a menu, one number a line:
in 8 px columns (a part column counting whole), or with --px in pixels, as the desktop's faces
draw it. Sumi UI's letters are 8 px, and 16 px where East Asian width says W or F (a kanji, a
kana, a full-width sign) — nothing else: every other sign is drawn into one column
(tools/build-fonts.py); the Sumi Icons (plane 15) are as wide as art/icons.txt makes them (16 px
for most: their width in whole 8 px columns); combining marks and joiners take nothing. (Arabic,
in Noto Kufi, is narrower than a column a letter: counted as one, it errs on the safe side.)"""
import pathlib
import re
import sys
import unicodedata

HERE = pathlib.Path(__file__).resolve().parent
COL = 8


def icon_advances():
    """U+FE000 onwards, in art/icons.txt's order: each icon's advance (adv=, else its width in
    whole 8 px columns — tools/build-icons.py's own rule)."""
    adv, cur = [], None
    for line in (HERE.parent.parent / "art/icons.txt").read_text(encoding="utf-8").splitlines():
        if line.startswith("@"):
            if cur:
                adv.append(cur["adv"] if cur["adv"] is not None else -(-cur["w"] // COL) * COL)
            m = re.search(r"\badv=(-?\d+)", line)
            cur = {"adv": int(m.group(1)) if m else None, "w": 0}
        elif cur and line and set(line) <= {"#", "."}:
            cur["w"] = max(cur["w"], len(line))
    if cur:
        adv.append(cur["adv"] if cur["adv"] is not None else -(-cur["w"] // COL) * COL)
    return adv


ICONS = icon_advances()


def px(c):
    o = ord(c)
    if 0xFE000 <= o < 0xFE000 + len(ICONS):
        return ICONS[o - 0xFE000]
    if 0xF0000 <= o <= 0xFFFFD:
        return 2 * COL
    if unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0
    return 2 * COL if unicodedata.east_asian_width(c) in ("W", "F") else COL


def cols(s):
    return -(-sum(px(c) for c in s) // COL)


if __name__ == "__main__":
    measure = (lambda s: sum(px(c) for c in s)) if sys.argv[1:] == ["--px"] else cols
    for line in sys.stdin.buffer.read().decode("utf-8", "replace").split("\n")[:-1]:
        print(measure(line))
