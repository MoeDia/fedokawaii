#!/usr/bin/env python3
# width.py REPO — how many 8 px menu columns each line on stdin takes in a menu, one number a
# line (two decimals). The measure is tests/menus/cols.py's:
# Sumi UI's letters, its two-column ones, the icons' own advances. A line that is not
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
    print(f"{sum(px(c) for c in s) / 8:.2f}")
