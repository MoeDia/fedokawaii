#!/usr/bin/env python3
"""tools/saver-review.py FRAMES SHEET.png OUT.webp — the screensaver's own frames (kawa-saver-render, tools/saver-review.sh) for his
page: the wake's side by side, and a recording as an animated WebP: asleep, the wake in real time, the lock held, then the wake
again at a third of it. FRAMES: step-N.ppm at 12 a second, wake-MS.ppm at 144 a second. Needs Pillow."""
import pathlib
import sys

from PIL import Image

frames, sheet, out = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
view = (1280, 720)
steps = sorted(frames.glob("step-*.ppm"))
wake = sorted(frames.glob("wake-*.ppm"))
if not steps or not wake:
    raise SystemExit(f"{frames}: no frames")
pick = [wake[round(i * (len(wake) - 1) / 11)] for i in range(12)]
cols = 4
rows = (len(pick) + cols - 1) // cols
S = Image.new("RGB", (cols * 644, rows * 364), (90, 90, 90))
for i, f in enumerate(pick):
    S.paste(Image.open(f).convert("RGB").resize((640, 360), Image.LANCZOS), (i % cols * 644, i // cols * 364))
S.save(sheet)
# (a page clamps a frame under 20 ms: the wake's every third, 21 ms each)
woke = wake[::3]
seq = steps + woke + [wake[-1]] + woke + [wake[-1]]
durs = [83] * len(steps) + [21] * len(woke) + [1400] + [63] * len(woke) + [1400]
pics = {}
for f in seq:
    if f not in pics:
        pics[f] = Image.open(f).convert("RGB").resize(view, Image.LANCZOS)
first, *rest = [pics[f] for f in seq]
first.save(out, format="WEBP", save_all=True, append_images=rest, duration=durs, loop=0, quality=78, method=2)
print(f"{out}: {len(seq)} frames; the wake {len(wake)} frames, {len(woke)} shown")
