#!/usr/bin/env python3
"""tests/menus/cols.py — how many columns of a menu each line on stdin takes, one number a
line: as fuzzel lays it out in the desktop's fonts. Departure Mono letters are one column;
the Sumi Icons (plane 15, the desktop's pixel icons) and wide East Asian characters (PixelMplus,
emoji) two; combining marks and joiners none. (Arabic, in Noto Kufi, is narrower than a
column per letter: counting it as one errs on the safe side.)"""
import sys
import unicodedata


def cols(s):
    n = 0
    for c in s:
        o = ord(c)
        if 0xF0000 <= o <= 0xFFFFD:
            n += 2
        elif unicodedata.combining(c) or unicodedata.category(c) in ("Mn", "Me", "Cf"):
            n += 0
        elif unicodedata.east_asian_width(c) in ("W", "F"):
            n += 2
        else:
            n += 1
    return n


for line in sys.stdin.buffer.read().decode("utf-8", "replace").split("\n")[:-1]:
    print(cols(line))
