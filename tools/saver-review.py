#!/usr/bin/env python3
"""tools/saver-review.py FRAMES PTS SHEET.png OUT.webp — one recording of the screensaver (tools/saver-review.sh): the wake's
frames side by side, and the recording as an animated WebP his page plays: its last 8 s asleep, the wake at real speed, the lock
held, then the wake again at a third of it. FRAMES: its pictures; PTS: their times, one a line (ffprobe). Needs Pillow, numpy."""
import pathlib
import sys

import numpy as np
from PIL import Image

frames, pts, sheet, out = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
names = sorted(frames.glob("*.png"))
times = [float(x.strip().strip(",")) for x in open(pts) if x.strip()][:len(names)]
ims = [Image.open(n).convert("RGB") for n in names]
# the wake: round the frame where the figure's place changes the most (the fires breathe, the middle does not)
mid = [np.asarray(im.resize((160, 90), Image.BILINEAR), dtype=np.int16)[20:70, 50:110] for im in ims]
moved = [0.0] + [float(np.abs(x - y).mean()) for x, y in zip(mid[1:], mid[:-1], strict=True)]
peak = int(np.argmax(moved))
start, end = max(0, peak - 3), min(len(ims) - 1, peak + 8)
wake = ims[start:end + 1]
pick = wake if len(wake) <= 12 else [wake[round(i * (len(wake) - 1) / 11)] for i in range(12)]
cols = 4
rows = (len(pick) + cols - 1) // cols
S = Image.new("RGB", (cols * 644, rows * 364), (90, 90, 90))
for i, im in enumerate(pick):
    S.paste(im.resize((640, 360), Image.LANCZOS), (i % cols * 644, i // cols * 364))
S.save(sheet)


def dur(k):
    return max(20, int(((times[k + 1] - times[k]) if k + 1 < len(times) else 0.2) * 1000))


view = (1280, 720)
first = next((k for k in range(start) if times[start] - times[k] <= 8.0), 0)
seq = list(range(first, end + 1))
durs = [dur(k) for k in seq]
durs[-1] = 1400
again = list(range(start, end + 1))
seq += again
durs += [dur(k) * 3 for k in again]
durs[-1] = 1400
pics = [ims[k].resize(view, Image.LANCZOS) for k in seq]
pics[0].save(out, format="WEBP", save_all=True, append_images=pics[1:], duration=durs, loop=0, quality=80, method=2)
print(f"the wake: {len(wake)} frames, {1000 * (times[end] - times[start]):.0f} ms recorded; {len(seq)} in the recording")
