#!/usr/bin/env python3
# width.py — how many menu columns each line on stdin takes in fuzzel, one number per line.
# A column is Departure Mono's 7 px advance at 11 px (fuzzel.ini). Sumi Icons glyphs take
# their own advance (art/icons.txt: "adv=N", else the drawing's width + 4 px), CJK falls back
# to PixelMplus12 (12 px), everything else is counted as one column. A line that is not valid
# UTF-8 prints "bad".
import re
import sys
import unicodedata

REPO = sys.argv[1]
icons, cur = [], None
for raw in open(f"{REPO}/art/icons.txt", encoding="utf-8").read().splitlines():
    line = raw.rstrip()
    if cur is None and (line == "#" or line.startswith("# ")):
        continue
    if line.startswith("@"):
        name, *opts = line[1:].split()
        cur = {"name": name, "rows": []}
        for o in opts:
            k, _, v = o.partition("=")
            cur[k] = int(v)
        icons.append(cur)
    elif re.fullmatch(r"[#.]+", line) and cur is not None:
        cur["rows"].append(line)
    elif not line:
        cur = None
ADV = {0xFE000 + i: ic.get("adv", len(ic["rows"][0]) + 4) for i, ic in enumerate(icons)}

for raw in sys.stdin.buffer.read().split(b"\n")[:-1]:
    try:
        s = raw.decode("utf-8")
    except UnicodeDecodeError:
        print("bad")
        continue
    px = 0
    for ch in s:
        o = ord(ch)
        if o in ADV:
            px += ADV[o]
        elif unicodedata.combining(ch):
            continue
        elif unicodedata.east_asian_width(ch) in "WF":
            px += 12
        else:
            px += 7
    print(f"{px / 7:.2f}")
