#!/usr/bin/env python3
"""tools/build-saver.py — what kawa-saver needs from the lock's own art, per mood, in saver-scene.txt: the painting
with no figure (lock-bare.png, the painter's; a scene of whole pixels, tools/build-lock.py's, its own bare scene
scaled up: saver-wall.png), the fires and the lock's strips but those tied to the figure (fig-…), in the painting's
pixels. The saver opens onto the real lock when a key comes: it never holds the figure.
    python3 tools/build-saver.py [--art DIR]     DIR: the folder of dark/ and light/ (default the repository's)
Run it after any change to the lock's art (tests/look/test_saver.sh says when it was forgotten). Needs python3-pillow."""
import argparse
import hashlib
import importlib.util
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY = (255, 0, 255)                        # (a picture of whole pixels: where a flame has nothing)
REACH = {"dark": 700, "light": 620}        # how far a fire's pool reaches, in pixels at 1920 × 1080
SIZE = (1920, 1080)


def words_of(path):
    kv = {}
    for line in open(path, encoding="utf-8"):
        w = line.split("#")[0].split()
        if w:
            kv.setdefault(w[0], []).append(w[1:])
    return kv


def pixel_scene(mood):
    """the bare scene of tools/build-lock.py, a picture of whole pixels"""
    sys.path.insert(0, str(ROOT / "tools"))
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("build_lock", ROOT / "tools/build-lock.py")
    bl = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bl)
    if mood == "dark":
        return bl.dark_scene().convert("RGB")
    ground, front, _ = bl.light_scene()
    ground = ground.convert("RGBA")
    ground.paste(front, (0, 0), front)
    return ground.convert("RGB")


def build(d, mood):
    kv = words_of(d / "lock-scene.txt")
    out = []
    bare = d / "lock-bare.png"
    w, h = (int(v) for v in kv["size"][0])
    if bare.exists():
        k = 1
        if Image.open(bare).size != SIZE:
            raise SystemExit(f"{bare}: {Image.open(bare).size}, not {SIZE}")
        wall = bare.name
    else:                                  # (a scene of whole pixels: as the lock shows it, whole)
        k = SIZE[0] // w
        pixel_scene(mood).resize(SIZE, Image.NEAREST).save(d / "saver-wall.png", optimize=True)
        wall = "saver-wall.png"
    out.append(f"size {SIZE[0]} {SIZE[1]}")
    out.append(f"wall {wall}   # the painting, the figure's place empty")
    plate = kv.get("centre", kv.get("plate", [[SIZE[0] // 2 // k, SIZE[1] * 46 // 100 // k, SIZE[1] // 5 // k]]))[0]
    cx, cy, cr = (int(v) * k for v in plate[:3])
    out.append(f"centre {cx} {cy} {min(cr, SIZE[1] // 5)}   # the figure's place: where the world opens, and how far the seal wanders from it")
    torches = [(int(a) * k, int(b) * k) for a, b in kv.get("torch", [])]
    anims = []
    for a in kv.get("anim", []):
        name, *vals = a
        if not name.startswith("fig-"):
            anims.append([f"lock-{name}.png", *(int(v) * k for v in vals[:4]), int(vals[4]), int(vals[5])])
    if not anims and "flame" in kv:        # (a scene of whole pixels: its flames, the lock's frames scaled up)
        fw, fh, n = (int(v) for v in kv["frames"][0])
        strip = Image.open(d / "lock-flame.png").convert("RGBA")
        strip.resize((strip.width * k, strip.height * k), Image.NEAREST).save(d / "saver-flame.png", optimize=True)
        for x, y in kv["flame"]:
            anims.append(["saver-flame.png", int(x) * k, int(y) * k, fw * k, fh * k, n, 1000 // 8])
            if "torch" not in kv:
                torches.append((int(x) * k + fw * k // 2, int(y) * k + fh * k * 3 // 5))
    for x, y in torches:
        out.append(f"torch {x} {y} {REACH[mood]}   # a fire: its middle, how far its pool reaches")
    for a in anims:
        out.append("anim " + " ".join(str(v) for v in a) + "   # a strip: file, place, a frame's size, frames, ms a frame")
    top = min((a[2] for a in anims), default=min(y for _, y in torches) - 200)
    out.append(f"ceiling {int(kv['ceiling'][0][0]) * k if 'ceiling' in kv else max(40, top - 170)}   # what stops the smoke")
    sums = hashlib.sha256()
    for f in sorted(d.glob("lock-*")):
        sums.update(f.name.encode() + f.read_bytes())
    out.append(f"lock {sums.hexdigest()[:16]}   # the lock's art it was built from (tests/look/test_saver.sh)")
    (d / "saver-scene.txt").write_text(
        "# saver-scene.txt — for kawa-saver: tools/build-saver.py wrote it from the lock's own art; in the painting's pixels.\n"
        + "\n".join(out) + "\n", encoding="utf-8")
    print(f"{mood}: {wall}, {len(torches)} fires, {len(anims)} strips, the middle {cx} {cy}")


ap = argparse.ArgumentParser(description="the screensaver's words, from the lock's art")
ap.add_argument("--art", type=pathlib.Path, default=ROOT / "configs/home/.local/share/fedokawaii")
args = ap.parse_args()
for m in ("dark", "light"):
    build(args.art / m, m)
