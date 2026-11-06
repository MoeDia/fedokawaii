#!/usr/bin/env python3
"""tools/lock-samurai-proof.py DIR — lock-samurai-proof.sh's reading of its recording: each frame's sprite by
exact match, the sequence with its measured times against lock-samurai.txt, stray pixels outside his cell and
the marks' row, the fake words in anything the run wrote. The pointer (one still box, the same in every
frame, measured from the first) is no stray; from the first frame after the last right pose on is dwl's dissolve
off the lock, its own business. Writes DIR/report.txt and DIR/sheet.png; exits 1 on anything wrong."""
import pathlib
import sys

import numpy as np
from PIL import Image

W = pathlib.Path(sys.argv[1])
X, Y, CW, CH, COLS, N = 284, 254, 72, 64, 8, 3
ROW = (270, 238, 370, 249)          # the marks' row, in the scene's pixels
scene = np.asarray(Image.open(W / "art/lock-scene.png").convert("RGB"))
strip = np.asarray(Image.open(W / "art/lock-samurai.png").convert("RGBA"))
under = scene[Y:Y + CH, X:X + CW]
sprites = []
for i in range(strip.shape[0] // CH * COLS):
    c = strip[i // COLS * CH:i // COLS * CH + CH, i % COLS * CW:i % COLS * CW + CW]
    sprites.append(np.where(c[..., 3:] > 0, c[..., :3], under))
names = {}
for line in (W / "art/lock-samurai.txt").read_text().splitlines():
    p = line.split()
    if p[0] != "cell":
        for t in p[2:]:
            names[int(t.split(":")[0])] = (p[0], int(t.split(":")[1]))

times = [float(t) for t in (W / "times.txt").read_text().split()]
files = sorted((W / "frames").glob("*.png"))
out, seq, strays, unknown = [], [], 0, 0
RIGHT_LAST = max(f for f, (n, _) in names.items() if n == "right")
first = np.asarray(Image.open(files[0]).convert("RGB"))
ys, xs = np.nonzero((first != np.repeat(np.repeat(scene, N, 0), N, 1)).any(2) & (np.arange(1920) < X * N)[None, :] & (np.arange(1080)[:, None] < ROW[1] * N))
PX0, PX1, PY0, PY1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1      # the pointer, on the screen
pointer = first[PY0:PY1, PX0:PX1].copy()
out_of_lock = 0
for path, t in zip(files, times, strict=True):
    a = np.asarray(Image.open(path).convert("RGB")).copy()
    assert a.shape[:2] == (1080, 1920)
    if seq and seq[-1][0] in (RIGHT_LAST, -2):
        out_of_lock += 1
        if not (a[PY0:PY1, PX0:PX1] == pointer).all() or seq[-1][0] == -2:
            seq.append([-2, t]) if seq[-1][0] != -2 else None
            continue
    if not (a[PY0:PY1, PX0:PX1] == pointer).all():
        strays += 1
        out.append(f"{path.name} t={t:.3f}: the pointer's box changed")
    a[PY0:PY1, PX0:PX1] = np.repeat(np.repeat(scene, N, 0), N, 1)[PY0:PY1, PX0:PX1]
    small = a[::N, ::N]
    if not (a == np.repeat(np.repeat(small, N, 0), N, 1)).all():
        strays += 1
        out.append(f"{path.name}: not whole 3 x 3 pixels")
    cell = small[Y:Y + CH, X:X + CW]
    hit = [i for i, s in enumerate(sprites) if (s == cell).all()]
    if not hit:
        unknown += 1
        out.append(f"{path.name} t={t:.3f}: his cell matches no sprite, {min(int((s != cell).any(2).sum()) for s in sprites)} px off the nearest")
    diff = (small != scene).any(2)
    diff[Y:Y + CH, X:X + CW] = False
    diff[ROW[1]:ROW[3], ROW[0]:ROW[2]] = False
    if diff.any():
        strays += 1
        ys, xs = np.nonzero(diff)
        out.append(f"{path.name} t={t:.3f}: {len(xs)} stray px, x {xs.min()}..{xs.max()} y {ys.min()}..{ys.max()}")
    f = hit[-1] if hit else -1
    if not seq or seq[-1][0] != f:
        seq.append([f, t])

rows = []
for (f, t), nxt in zip(seq, seq[1:] + [[None, times[len(files) - 1]]], strict=True):
    name, want = ("dissolve", 0) if f == -2 else names.get(f, ("?", 0))
    rows.append(f"{t:8.3f}  frame {f:2d}  {name:7s} held {1000 * (nxt[1] - t):6.0f} ms, wanted {want}")
words = []
for path in W.glob("*"):
    if path.is_file() and path.suffix in (".log", ".txt") or path.name == "rc":
        data = path.read_bytes()
        if b"rightword" in data or b"abcdef" in data:
            words.append(path.name)
seen = {names[f][0] for f, _ in seq if f in names}
missing = sorted({n for n, _ in names.values()} - seen)
report = [f"{len(files)} frames ({out_of_lock} of them dwl's dissolve), {unknown} unmatched, {strays} with strays, pointer box {PX0},{PY0} {PX1 - PX0}x{PY1 - PY0}, states not seen: {missing or 'none'}, fake words in logs: {words or 'none'}", *out[:30], *rows]
(W / "report.txt").write_text("\n".join(report) + "\n")
print("\n".join(report))

# the sheet: his cell at 3 x (the screen's size) of the first frame of each change
cols = 12
cells = []
last = None
for path in files[:len(files) - out_of_lock]:
    a = np.asarray(Image.open(path).convert("RGB"))[Y * N - 45:(Y + CH) * N + 6, X * N - 30:(X + CW) * N + 30]
    k = a[45:].tobytes()
    if k != last:
        cells.append(a)
    last = k
h, w = cells[0].shape[:2]
rowsn = (len(cells) + cols - 1) // cols
sheet = np.zeros((rowsn * (h + 4), cols * (w + 4), 3), np.uint8)
for i, c in enumerate(cells):
    y, x = i // cols * (h + 4), i % cols * (w + 4)
    sheet[y:y + h, x:x + w] = c
Image.fromarray(sheet).save(W / "sheet.png")
sys.exit(1 if unknown or strays or missing or words else 0)
