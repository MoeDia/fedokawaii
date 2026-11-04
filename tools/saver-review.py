#!/usr/bin/env python3
"""tools/saver-review.py FRAMES SHEET.png OUT.webp — one recording of the screensaver (tools/saver-review.sh): the wake's frames
side by side, and the recording as an animated WebP his page plays: at most its last 8 s asleep at 12 frames a second (the wake
at every frame it was recorded), the last picture held. Needs Pillow, numpy."""
import pathlib
import sys

import numpy as np
from PIL import Image

frames, sheet, out = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
names = sorted(frames.glob("*.png"))
ims = [Image.open(n).convert("RGB") for n in names]
small = [np.asarray(im.resize((320, 180), Image.NEAREST), dtype=np.int16) for im in ims]
# the wake: where a frame's change from the one before is largest (dots opening), to where the picture stops changing much
moved = [0] + [int((np.abs(a - b).sum(-1) > 24).sum()) for a, b in zip(small[1:], small[:-1], strict=True)]
start = int(np.argmax(np.array(moved) > 900)) if max(moved) > 900 else len(ims) - 1
start = max(0, start - 1)
end = len(ims) - 1
for k in range(len(ims) - 1, start, -1):
    if moved[k] > 900:
        end = min(len(ims) - 1, k + 1)
        break
wake = ims[start:end + 1]
pick = wake if len(wake) <= 12 else [wake[round(i * (len(wake) - 1) / 11)] for i in range(12)]
cols = 4
rows = (len(pick) + cols - 1) // cols
S = Image.new("RGB", (cols * 644, rows * 364), (90, 90, 90))
for i, im in enumerate(pick):
    S.paste(im.resize((640, 360), Image.NEAREST), (i % cols * 644, i // cols * 364))
S.save(sheet)
# the recording at its shown size; asleep the frames are 12 a second, the wake as it was recorded
seq = ims[max(0, start - 96):start] + wake + [ims[-1]]
durs = [83] * len(ims[max(0, start - 96):start]) + [max(8, 1000 // 60)] * len(wake) + [1800]
seq[0].resize((1280, 720), Image.NEAREST).save(out, save_all=True, append_images=[f.resize((1280, 720), Image.NEAREST) for f in seq[1:]],
                                               duration=durs, loop=0, lossless=False, quality=86, method=2)
print(f"wake: {len(wake)} frames recorded; {len(seq)} in the recording")
