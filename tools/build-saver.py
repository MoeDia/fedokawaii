#!/usr/bin/env python3
"""tools/build-saver.py — the screensaver's pictures, from the lock's own (tools/build-lock.py): the scene with its
gate shut, dimmed, asleep, and the flames' frames on a key colour, as plain P6 files kawa-saver reads with no library.
    python3 tools/build-saver.py     writes configs/home/.local/share/fedokawaii/{dark,light}/saver-{scene,flame}.ppm
Run it after tools/build-lock.py. Needs python3-pillow."""
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIM = {"dark": 0.62, "light": 0.82}        # the scene's light, asleep
KEY = (255, 0, 255)                        # where a flame has nothing


def ppm(im, path):
    with open(path, "wb") as f:
        f.write(b"P6 %d %d 255\n" % im.size)
        f.write(im.tobytes())


for mood in ("dark", "light"):
    d = ROOT / "configs/home/.local/share/fedokawaii" / mood
    words = {}
    for line in open(d / "lock-scene.txt", encoding="utf-8"):
        w = line.split("#")[0].split()
        if w:
            words[w[0]] = w[1:]
    scene = Image.open(d / "lock-scene.png").convert("RGB")
    if "gate" in words:                    # (its frames side by side, shut first)
        gx, gy, gw, gh, _ = map(int, words["gate"])
        scene.paste(Image.open(d / "lock-gate.png").convert("RGB").crop((0, 0, gw, gh)), (gx, gy))
    k = DIM[mood]
    ppm(scene.point(lambda v, k=k: round(v * k)), d / "saver-scene.ppm")
    flame = Image.open(d / "lock-flame.png").convert("RGBA")
    out = Image.new("RGB", flame.size, KEY)
    out.paste(flame.convert("RGB"), (0, 0), flame.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    ppm(out, d / "saver-flame.ppm")
print("saver-scene.ppm, saver-flame.ppm: both moods")
