#!/usr/bin/env python3
# width.py REPO — how many 6 px menu columns each line on stdin takes in fuzzel, one number a
# line (two decimals: the Sumi Icons are 14 px for most). The measure is tests/menus/cols.py's:
# Fusion Pixel's letters, its two-column ones, the icons' own advances. A line that is not
# valid UTF-8 prints "bad".
import sys

sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
sys.path.insert(0, f"{sys.argv[1]}/tests/menus")
from cols import px  # noqa: E402

for raw in sys.stdin.buffer.read().split(b"\n")[:-1]:
    try:
        s = raw.decode("utf-8")
    except UnicodeDecodeError:
        print("bad")
        continue
    print(f"{sum(px(c) for c in s) / 6:.2f}")
