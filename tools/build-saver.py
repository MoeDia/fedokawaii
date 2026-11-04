#!/usr/bin/env python3
"""tools/build-saver.py — the screensaver's pictures, from the lock's own art (tools/build-lock.py): the
same painting, the same pixels, with no figure in it; kawa-saver lays the sleeping light over it, and when
a key comes opens it dot by dot onto the lock under it. Plain P6 files it reads with no library:
    python3 tools/build-saver.py     writes configs/home/.local/share/fedokawaii/{dark,light}/
      saver-scene.ppm    the painting, lit as the lock shows it, without the figure
      saver-flame.ppm    the lock's flames, side by side, on a key colour
      saver-scene.txt    the halo round the figure's place: its middle, its radii, its inks
Run it after tools/build-lock.py (tests/look/test_saver.sh says when it was forgotten). Needs python3-pillow."""
import hashlib
import importlib.util
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("build_lock", ROOT / "tools/build-lock.py")
bl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bl)
KEY = (255, 0, 255)                        # where a flame has nothing


def ppm(im, path):
    with open(path, "wb") as f:
        f.write(b"P6 %d %d 255\n" % im.size)
        f.write(im.tobytes())


def hexes(*names, inks=None):
    return [inks[n].lstrip("#") if isinstance(inks[n], str) else "%02x%02x%02x" % inks[n] for n in names]


def bare(mood):
    """the painting with no figure, what the lock's scene is drawn on (build-lock.py), and the ring of flames
    round the figure's place, as build-lock.py drew it: its middle, and how far its flames start and end"""
    ring = []
    drawn = bl.mandorla

    def seen(r, cx, cy, base=92, short=30, long_=56, **kw):
        ring.append((cx, cy, base, long_))
        return drawn(r, cx, cy, base, short, long_, **kw)

    bl.mandorla = seen
    if mood == "dark":
        scene = bl.dark_scene().convert("RGB")
    else:
        ground, front, _ = bl.light_scene()
        ground = ground.convert("RGBA")
        ground.paste(front, (0, 0), front)
        scene = ground.convert("RGB")
    bl.mandorla = drawn
    return scene, ring[0]


INKS = {"dark": ("accent", "accent_lo"), "light": ("gold",)}
RING_IN = 16                               # (the ring's inner edge lies this far inside the circle its flames start from)

for mood in ("dark", "light"):
    d = ROOT / "configs/home/.local/share/fedokawaii" / mood
    scene, (cx, cy, base, reach) = bare(mood)
    ppm(scene, d / "saver-scene.ppm")
    flame = Image.open(d / "lock-flame.png").convert("RGBA")
    out = Image.new("RGB", flame.size, KEY)
    out.paste(flame.convert("RGB"), (0, 0), flame.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    ppm(out, d / "saver-flame.ppm")
    pal = bl.D if mood == "dark" else bl.L
    inks = hexes(*INKS[mood], inks=pal)
    r0, r1 = base - RING_IN, base + reach
    lock = hashlib.sha256((d / "lock-scene.png").read_bytes() + (d / "lock-flame.png").read_bytes()).hexdigest()[:16]
    (d / "saver-scene.txt").write_text(
        "# saver-scene.txt — tools/build-saver.py wrote it; for kawa-saver, beside lock-scene.txt.\n"
        f"halo {cx} {cy} {r0} {r1} {' '.join(inks)}   # the ring round the figure's place: its middle, its radii, its inks\n"
        f"lock {lock}   # the lock's art it was drawn from (tests/look/test_saver.sh)\n")
    print(f"{mood}: halo {cx} {cy} {r0} {r1}")
print("saver-scene.ppm, saver-flame.ppm, saver-scene.txt: both moods")
