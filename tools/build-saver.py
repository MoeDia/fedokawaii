#!/usr/bin/env python3
"""tools/build-saver.py — what kawa-saver needs from the lock's own art, per mood, in saver-scene.txt: the painting
with no figure (lock-bare.png, the painter's; a scene of whole pixels, tools/build-lock.py's, its own bare scene
scaled up: saver-wall.png), the fires and the lock's strips but those tied to the figure (fig-…), in the painting's
pixels, and the time's seal (saver-seal.png). The saver opens onto the real lock when a key comes: it never holds the figure.
    python3 tools/build-saver.py [--art DIR]     DIR: the folder of dark/ and light/ (default the repository's)
Run it after any change to the lock's art (tests/look/test_saver.sh says when it was forgotten). Needs python3-pillow."""
import argparse
import hashlib
import importlib.util
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY = (255, 0, 255)                        # (a picture of whole pixels: where a flame has nothing)
REACH = {"dark": 700, "light": 620}        # how far a fire's pool reaches, in pixels at 1920 × 1080
SIZE = (1920, 1080)
SEAL = (62, 84)                            # the time's seal, in pixels: two rows of two digits
DIGIT = (25, 34)                           # a digit's cell in it
DIGIT_FONT = "/usr/share/fonts/google-noto-vf/NotoSerif[wght].ttf"   # (its shapes baked in here: google-noto-serif-vf, OFL)


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


def seal_atlas(path):
    """saver-seal.png, alpha only (kawa-saver inks it): the seal's body, cut from worn stone — an uneven edge, the ink thin in
    places, a thin line cut inside its edge — then the ten digits, each a mask to cut out of it: hakubun, the ground showing"""
    rng = np.random.default_rng(41)
    k = 4
    w, h = SEAL[0] * k, SEAL[1] * k
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) / k
    # (a coarse and a fine noise, smoothed: how the stone's edge wanders and where the ink took badly)
    coarse = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(k * 2.2)), float) / 255
    fine = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(k * 0.55)), float) / 255
    coarse = (coarse - coarse.mean()) / coarse.std()
    fine = (fine - fine.mean()) / fine.std()
    body = edge + coarse * 0.9 > 2.2                       # the edge
    line = np.abs(edge + coarse * 0.45 - 4.6) < 0.42       # the line cut inside it
    worn = fine + coarse * 0.35 > 2.05                     # where the ink did not take
    a = body & ~line & ~worn
    mottled = np.clip(0.93 + 0.05 * fine, 0.78, 1.0)
    alpha = np.where(a, mottled, 0.0)
    im = Image.fromarray((alpha * 255).astype(np.uint8)).resize(SEAL, Image.LANCZOS)
    font = ImageFont.truetype(DIGIT_FONT, 33)
    font.set_variation_by_name("Bold")
    strip = Image.new("L", (SEAL[0] + DIGIT[0] * 10, SEAL[1]), 0)
    strip.paste(im, (0, 0))
    for i in range(10):
        cell = Image.new("L", (DIGIT[0] * 4, DIGIT[1] * 4), 0)
        big = ImageFont.truetype(DIGIT_FONT, 33 * 4)
        big.set_variation_by_name("Bold")
        d = ImageDraw.Draw(cell)
        x0, y0, x1, y1 = d.textbbox((0, 0), str(i), font=big)
        d.text(((DIGIT[0] * 4 - (x1 - x0)) / 2 - x0, (DIGIT[1] * 4 - (y1 - y0)) / 2 - y0), str(i), font=big, fill=255)
        strip.paste(cell.resize(DIGIT, Image.LANCZOS), (SEAL[0] + i * DIGIT[0], 0))
    rgba = Image.merge("RGBA", (Image.new("L", strip.size, 255), Image.new("L", strip.size, 255), Image.new("L", strip.size, 255), strip))
    rgba.save(path, optimize=True)


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
    seal_atlas(d / "saver-seal.png")
    out.append(f"seal {SEAL[0]} {SEAL[1]} {DIGIT[0]} {DIGIT[1]}   # saver-seal.png, its alpha: the seal, then the ten digits")
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
