#!/usr/bin/env python3
"""tools/build-saver.py — what kawa-saver needs from the lock's own art, per mood, in saver-scene.txt: the lock's painting
(lock-scene.png) and a patch over it with the figure asleep (saver-lids.png: the mask's eyes shut and its jaw, re-cut by
tools/build-ink.py's engraver; the angel's eyes shut, her head bowed, her halo out), the lock's own flames, and the time's seal
(saver-seal.png). A key opens the sleeper's picture onto the real lock: every pixel outside the patch is the lock's.
    python3 tools/build-saver.py [--art DIR]     DIR: the folder of dark/ and light/ (default the repository's)
Run it after any change to the lock's art (tests/look/test_saver.sh says when it was forgotten). Needs python3-pillow, numpy,
scipy, and for the mask tools/build-ink.py's sources (art/ink/SOURCES.md)."""
import argparse
import hashlib
import importlib.util
import pathlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage as ndi

ROOT = pathlib.Path(__file__).resolve().parent.parent
REACH = {"dark": 560, "light": 620}        # how far a fire's pool reaches, in pixels at 1920 × 1080
SIZE = (1920, 1080)
SLEEPER = {"dark": (440, 0, 1480, 1080), "light": (700, 0, 1600, 1010)}   # what of the sleeper's frame goes over the lock: the figure, its gate
FIGURE = {"dark": (960, 565, 560), "light": (1002, 420, 620)}   # where the sleeper breathes: its middle (the wake starts there), the reach of its light
SPOTS = {"dark": ((1330, 720), (560, 400), (1360, 400), (590, 720)),    # where the seal lands, in turn, every move across the frame: its thirds, clear of the figure
         "light": ((1370, 720), (510, 520), (1370, 400), (570, 750))}   # (the left ones clear of her quote's plaque, x 558–615 to y 330)
FLAME_MS = 125                             # a flame's frame, 8 a second as on the lock
SEAL = (168, 228)                          # the time's seal, in pixels: two rows of two digits
DIGIT = (68, 92)                           # a digit's cell in it
SEAL_K = 2.7                               # (the seal's edge, its line and its wear are drawn at this many times their first size)
DIGIT_FONT = "/usr/share/fonts/google-noto-vf/NotoSerif[wght].ttf"   # (its shapes baked in here: google-noto-serif-vf, OFL)


def words_of(path):
    kv = {}
    for line in open(path, encoding="utf-8"):
        w = line.split("#")[0].split()
        if w:
            kv.setdefault(w[0], []).append(w[1:])
    return kv


def seal_atlas(path):
    """saver-seal.png, alpha only (kawa-saver inks it): the seal's body, cut from worn stone — an uneven edge, the ink thin in
    places, a thin line cut inside its edge — then the ten digits, each a mask to cut out of it: hakubun, the ground showing"""
    rng = np.random.default_rng(41)
    k = 4
    w, h = SEAL[0] * k, SEAL[1] * k
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) / (k * SEAL_K)
    # (a coarse and a fine noise, smoothed: how the stone's edge wanders and where the ink took badly)
    coarse = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(k * SEAL_K * 2.2)), float) / 255
    fine = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(k * 0.9)), float) / 255
    coarse = (coarse - coarse.mean()) / coarse.std()
    fine = (fine - fine.mean()) / fine.std()
    body = edge + coarse * 0.9 > 2.2                       # the edge
    line = np.abs(edge + coarse * 0.45 - 4.6) < 0.42       # the line cut inside it
    worn = fine + coarse * 0.35 > 2.05                     # where the ink did not take
    a = body & ~line & ~worn
    mottled = np.clip(0.93 + 0.05 * fine, 0.78, 1.0)
    alpha = np.where(a, mottled, 0.0)
    im = Image.fromarray((alpha * 255).astype(np.uint8)).resize(SEAL, Image.LANCZOS)
    strip = Image.new("L", (SEAL[0] + DIGIT[0] * 10, SEAL[1]), 0)
    strip.paste(im, (0, 0))
    big = ImageFont.truetype(DIGIT_FONT, int(33 * SEAL_K * 4))
    big.set_variation_by_name("Bold")
    for i in range(10):
        cell = Image.new("L", (DIGIT[0] * 4, DIGIT[1] * 4), 0)
        d = ImageDraw.Draw(cell)
        x0, y0, x1, y1 = d.textbbox((0, 0), str(i), font=big)
        d.text(((DIGIT[0] * 4 - (x1 - x0)) / 2 - x0, (DIGIT[1] * 4 - (y1 - y0)) / 2 - y0), str(i), font=big, fill=255)
        # (cut by hand: the chisel's edge wanders a little, nothing like a typeface's)
        a = np.asarray(cell.filter(ImageFilter.GaussianBlur(k * .7)), float) / 255
        n = np.asarray(Image.fromarray((rng.random((DIGIT[1] * 4, DIGIT[0] * 4)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(k * 1.1)), float) / 255
        cell = Image.fromarray(((a + (n - n.mean()) / n.std() * .10 > .5) * 255).astype(np.uint8))
        strip.paste(cell.resize(DIGIT, Image.LANCZOS), (SEAL[0] + i * DIGIT[0], 0))
    rgba = Image.merge("RGBA", (Image.new("L", strip.size, 255), Image.new("L", strip.size, 255), Image.new("L", strip.size, 255), strip))
    rgba.save(path, optimize=True)


# ── the figure asleep ────────────────────────────────────────────────────────────────

MASK_CROP = (652, 1330)                    # the mask's photograph (tools/build-ink.py's source): where these points were read from
MASK_PLATES = (
    # a gold eye plate's edge; its lash line: outer corner, inner corner, how far it sags
    ([(82, 190), (92, 130), (118, 85), (150, 68), (200, 72), (260, 82), (330, 95), (400, 100), (470, 105), (510, 110), (530, 135), (542, 190),
      (535, 240), (510, 280), (470, 310), (420, 330), (350, 332), (280, 315), (210, 285), (150, 255), (100, 225)], (96, 196), (534, 222), 84),
    ([(716, 190), (725, 135), (745, 100), (800, 95), (880, 98), (950, 88), (1030, 75), (1090, 68), (1125, 80), (1148, 120), (1160, 170),
      (1155, 225), (1120, 255), (1060, 285), (980, 310), (900, 325), (830, 325), (780, 300), (745, 260), (725, 225)], (722, 216), (1156, 186), 86),
)
LID_SKIN = np.array([.70, .46, .33], np.float32)   # the mask's own wood, round the plates


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def eyes_shut(a):
    """the mask's photograph with both gold plates become closed lids, in tones: tools/build-ink.py's engraver cuts them as it cuts
    the rest of the face. The ball under the lid catches the light from above; a fold above it; one heavy cut for the lash, thin at
    its ends; below it the lower lid, a narrow lit lip, then the socket's shadow"""
    out = a.copy()
    rng = np.random.default_rng(3)
    for poly, (cx0, cy0), (cx1, cy1), sag in MASK_PLATES:
        pts = [(x + MASK_CROP[0], y + MASK_CROP[1]) for x, y in poly]
        cx0, cy0, cx1, cy1 = cx0 + MASK_CROP[0], cy0 + MASK_CROP[1], cx1 + MASK_CROP[0], cy1 + MASK_CROP[1]
        x0, x1 = min(p[0] for p in pts) - 40, max(p[0] for p in pts) + 40
        y0, y1 = min(p[1] for p in pts) - 40, max(p[1] for p in pts) + 40
        im = Image.new("L", (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(im).polygon([(x - x0, y - y0) for x, y in pts], fill=255)
        hard = ndi.binary_dilation(np.asarray(im, np.float32) > 127, iterations=5)   # (past the plate's bright rim)
        cover = ndi.gaussian_filter(hard.astype(np.float32), 3.0)[..., None]
        yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
        u = np.clip((xx - cx0) / (cx1 - cx0), 0, 1)
        lash = cy0 + (cy1 - cy0) * u + sag * 4 * u * (1 - u)
        top = np.where(hard, yy, 1e9).min(axis=0, keepdims=True)
        top = np.where(top > 1e8, float(y0), top)
        v = np.clip((yy - top) / np.maximum(lash - top, 1), 0, 1)
        lid = .46 + .30 * smooth(0, .26, v) - .22 * smooth(.66, 1, v)
        lid *= 1 - .34 * smooth(.55, 1, np.abs(u - .5) * 2)
        fold = top + (lash - top) * .24 - 6 * np.sin(np.pi * u)
        lid *= 1 - .70 * np.exp(-((yy - fold) / 4.5) ** 2) * smooth(.10, .34, u) * smooth(.10, .34, 1 - u)
        below = np.clip((yy - lash) / 44, 0, 1)
        tone = np.where(yy > lash, .84 - .34 * smooth(.5, 1, below), lid)
        wobble = ndi.gaussian_filter1d(rng.normal(0, 1, x1 - x0).astype(np.float32), 22) * 16
        thick = 4.5 + 7.5 * np.maximum(np.sin(np.pi * u), 0) ** .7
        tone = np.where(np.abs(yy - lash - wobble[None, :]) < thick, .02, tone)
        tone = np.where((yy > lash) & (yy < lash + thick + 11), tone * .62, tone)
        grain = ndi.gaussian_filter(rng.normal(0, 1, tone.shape).astype(np.float32), 2.4)
        tone = np.clip(tone + grain * .16 * (tone > .05), 0, 1)
        grey = (tone + .05) / 1.25                         # (the engraver's tone in an eye: its grey × 1.25 − .05; its grey: mostly red)
        base = LID_SKIN[0] * .75 + float(LID_SKIN @ np.array([.3, .59, .11], np.float32)) * .25
        rgb = np.clip(LID_SKIN[None, None, :] * (grey / base)[..., None], 0, 1)
        out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1 - cover) + rgb * cover
    return out


def ink_tool():
    sp = importlib.util.spec_from_file_location("build_ink", ROOT / "tools/build-ink.py")
    bi = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(bi)
    return bi


def asleep_dark():
    """the lock's own frame with the jaw shut, the mask's eyes shut, no flames (their strips lie over it)"""
    bi = ink_tool()
    L = bi.dark_layers()
    return to_image(bi.dark_frame(L, 0, eyes_shut(L["a"]), flames=False))


def to_image(f):
    return Image.fromarray((np.clip(f, 0, 1) * 255 + .5).astype(np.uint8))


# the angel's eyes on the screen, in pixels: what is taken out of her lines, the lid's line that takes its place (three points on it, a sag)
ANGEL_EYES = (
    ([(995, 175), (1000, 173), (1007, 173), (1011, 176), (1011, 180), (1006, 182.5), (1000, 182), (996, 179)], ((996.6, 176.4), (1003.2, 180.8), (1010.2, 178.8))),
    ([(1027, 179), (1033, 178), (1039, 179), (1039.5, 185), (1034, 186.5), (1029, 185)], ((1027.2, 180), (1032.8, 184.2), (1039, 182.2))),
)
BOW = (977, 240, 8.5, (1002, 186), 78, 158)   # her head bowed: the neck it turns on, by how much, where wholly turned, the reach of that, where it fades out
ANGEL_HEAD = (985, 196)                    # tools/build-ink.py's HEAD these points were read against


def angel_eyes_shut(ink):
    """her lines with both eyes shut: the eye's opening clean, one fine arc for the lid, three short lashes"""
    k = 4
    x0, y0, w, h = 985, 160, 70, 40
    wipe = Image.new("L", (w * k, h * k), 0)
    line = Image.new("L", (w * k, h * k), 0)
    dw, dl = ImageDraw.Draw(wipe), ImageDraw.Draw(line)
    for poly, (a, b, c) in ANGEL_EYES:
        dw.polygon([((x - x0) * k, (y - y0) * k) for x, y in poly], fill=255)
        pts = []
        for i in range(25):
            t = i / 24
            pts.append((((1 - t) ** 2 * a[0] + 2 * t * (1 - t) * (2 * b[0] - (a[0] + c[0]) / 2) + t * t * c[0] - x0) * k,
                        ((1 - t) ** 2 * a[1] + 2 * t * (1 - t) * (2 * b[1] - (a[1] + c[1]) / 2) + t * t * c[1] - y0) * k))
        dl.line(pts, fill=255, width=int(1.3 * k))
        for t in (.42, .6, .78):                           # (the lashes: short, down and outward)
            q = pts[round(t * 24)]
            dl.line([q, (q[0] + 1.1 * k, q[1] + 1.9 * k)], fill=200, width=int(.6 * k))
    a = np.asarray(wipe.resize((w, h), Image.BOX), np.float32) / 255
    b = np.asarray(line.resize((w, h), Image.BOX), np.float32) / 255
    out = ink.copy()
    out[y0:y0 + h, x0:x0 + w] = np.maximum(out[y0:y0 + h, x0:x0 + w] * (1 - a), b)
    return out


def bowed(a):
    """a picture (2 or 3 axes) with her head turned forward on the neck, fading out through the hair: the curls take up the seam"""
    px, py, deg, (hx, hy), r0, r1 = BOW
    H, W = a.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    w = 1 - smooth(r0, r1, np.hypot(xx - hx, yy - hy))
    th = np.radians(deg) * w
    dx, dy = xx - px, yy - py
    sx = px + dx * np.cos(th) + dy * np.sin(th)            # (where each pixel comes from: turned back)
    sy = py - dx * np.sin(th) + dy * np.cos(th)
    y0, y1, x0, x1 = hy - r1 - 4, hy + r1 + 4, hx - r1 - 4, hx + r1 + 4
    box = (sy[y0:y1, x0:x1], sx[y0:y1, x0:x1])
    out = a.copy()
    if a.ndim == 2:
        out[y0:y1, x0:x1] = np.clip(ndi.map_coordinates(a, box, order=3), 0, 1)     # (a spline: her fine lines stay fine)
    else:
        for i in range(a.shape[2]):
            out[y0:y1, x0:x1, i] = np.clip(ndi.map_coordinates(a[..., i], box, order=3), 0, 1)
    return out


def asleep_light():
    """the lock's own frame with the scroll rolled and sealed: her eyes shut, her head bowed, the halo down to a trace, no rays"""
    bi = ink_tool()
    if tuple(bi.HEAD) != ANGEL_HEAD:
        raise SystemExit(f"the angel moved ({bi.HEAD}, not {ANGEL_HEAD}): read ANGEL_EYES and BOW off her new place")
    ring = bi.halo_ring
    bi.halo_ring = lambda: ring() * .16                    # (all her layers as the lock's but this)
    L = dict(bi.light_layers())
    fi = bowed(angel_eyes_shut(L["fig_i"]))
    L["fig_a"], L["body"] = bowed(L["fig_a"]), bowed(L["body"])
    return to_image(bi.light_frame(L, 0, a_ink=fi))


ASLEEP = {"dark": asleep_dark, "light": asleep_light}


def patch_of(lock, sleeping, box, path):
    """what differs between the lock and its sleeper in BOX, as one patch: (x, y) of it"""
    a, b = np.asarray(lock.convert("RGB"), np.int16), np.asarray(sleeping.convert("RGB"), np.int16)
    ys, xs = np.nonzero(np.abs(a - b)[box[1]:box[3], box[0]:box[2]].max(-1) > 1)
    if not len(xs):
        raise SystemExit(f"{path}: the sleeper is the lock")
    x0, x1, y0, y1 = int(xs.min()) + box[0], int(xs.max()) + box[0] + 1, int(ys.min()) + box[1], int(ys.max()) + box[1] + 1
    sleeping.convert("RGB").crop((x0, y0, x1, y1)).save(path, optimize=True)
    return x0, y0


def build(d, mood, sleeping=None):
    kv = words_of(d / "lock-scene.txt")
    out = []
    lock = Image.open(d / "lock-scene.png").convert("RGB")
    if lock.size != SIZE:
        raise SystemExit(f"{d / 'lock-scene.png'}: {lock.size}, not {SIZE}")
    sleeping = sleeping or ASLEEP[mood]()
    px, py = patch_of(lock, sleeping, SLEEPER[mood], d / "saver-lids.png")
    out.append(f"size {SIZE[0]} {SIZE[1]}")
    out.append("wall lock-scene.png   # the lock's own painting")
    out.append(f"patch saver-lids.png {px} {py}   # over it, the figure asleep")
    cx, cy, rest = FIGURE[mood]
    out.append(f"centre {cx} {cy}   # the figure's place: where the world opens")
    out.append(f"rest {rest}   # how far the sleeper's own light reaches")
    for x, y in SPOTS[mood]:
        out.append(f"spot {x} {y}   # where the seal lands")
    # the fires: the lock's own flames, the same frames in the same places (each its own pace: they never beat together)
    fw, fh, n = (int(v) for v in kv["frames"][0])
    anims = [["lock-flame.png", int(x), int(y), fw, fh, n, FLAME_MS + 13 * i] for i, (x, y) in enumerate(kv["flame"])]
    for a in anims:
        out.append("anim " + " ".join(str(v) for v in a) + "   # a strip: file, place, a frame's size, frames, ms a frame")
    for a in anims:
        out.append(f"torch {a[1] + fw // 2} {a[2] + fh // 2} {REACH[mood]}   # a fire: its middle, how far its pool reaches")
    top = min(a[2] for a in anims)
    out.append(f"ceiling {int(kv['ceiling'][0][0]) if 'ceiling' in kv else max(40, top - 170)}   # what stops the smoke")
    seal_atlas(d / "saver-seal.png")
    out.append(f"seal {SEAL[0]} {SEAL[1]} {DIGIT[0]} {DIGIT[1]}   # saver-seal.png, its alpha: the seal, then the ten digits")
    sums = hashlib.sha256()
    for f in sorted(d.glob("lock-*")):
        sums.update(f.name.encode() + f.read_bytes())
    out.append(f"lock {sums.hexdigest()[:16]}   # the lock's art it was built from (tests/look/test_saver.sh)")
    (d / "saver-scene.txt").write_text(
        "# saver-scene.txt — for kawa-saver: tools/build-saver.py wrote it from the lock's own art; in the painting's pixels.\n"
        + "\n".join(out) + "\n", encoding="utf-8")
    print(f"{mood}: patch at {px} {py}, {len(anims)} fires, the middle {cx} {cy}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="the screensaver's words, from the lock's art")
    ap.add_argument("--art", type=pathlib.Path, default=ROOT / "configs/home/.local/share/fedokawaii")
    args = ap.parse_args()
    for m in ("dark", "light"):
        build(args.art / m, m)
