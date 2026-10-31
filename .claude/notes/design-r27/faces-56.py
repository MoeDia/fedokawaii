"""The dial's middle face, 56 × 56, drawn on the left half and mirrored (exact symmetry)."""
import math, sys
from PIL import Image
W = H = 56
HALF = 28

def blank(): return [["."] * HALF for _ in range(H)]
def put(g, x, y, c):
    x, y = int(x), int(y)
    if 0 <= x < HALF and 0 <= y < H: g[y][x] = c
def poly(g, pts, c):
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        xs = []
        n = len(pts)
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if (y1 <= y + .5 < y2) or (y2 <= y + .5 < y1):
                xs.append(x1 + (y + .5 - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[::2], xs[1::2]):
            for x in range(int(math.ceil(a - .5)), int(math.floor(b - .5)) + 1):
                put(g, x, y, c)
def line(g, x0, y0, x1, y1, c, w=1):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for dx in range(w):
            put(g, round(x - .5) + dx, round(y - .5), c)
def ell(g, cx, cy, rx, ry, c, ring=None):
    for y in range(H):
        for x in range(HALF):
            d = ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2
            if d <= 1 and (ring is None or d >= ring):
                put(g, x, y, c)
def outline(g, fillset, c):
    """c on every empty pixel next to (4-way) a pixel of fillset."""
    out = [r[:] for r in g]
    for y in range(H):
        for x in range(HALF):
            if g[y][x] == ".":
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < HALF and 0 <= yy < H and g[yy][xx] in fillset:
                        out[y][x] = c
                        break
    return out
def mirror(g):
    return ["".join(r) + "".join(reversed(r)) for r in g]

def hannya():
    g = blank()
    # the horns: thick at the base on the forehead's corners, curving out then up, ringed in sumi
    poly(g, [(14, 16), (20, 13), (17, 8), (12, 3), (9, 1), (8, 2), (10, 7), (11, 12)], "G")
    for (x0, y0, x1, y1) in ((9, 5, 13, 3), (10, 9, 16, 6), (12, 13, 19, 10)):
        line(g, x0, y0, x1, y1, "K")
    # the mask: a high forehead between the horns, broad at the cheekbones, the jaw wide for the
    # mouth, narrowing to a pointed chin
    poly(g, [(28, 9), (21, 10), (15, 14), (11, 19), (9, 25), (8, 31), (9, 37), (11, 42), (15, 47), (20, 51), (25, 54), (28, 55)], "W")
    # the hair at the temples and two strands painted down from the parting
    poly(g, [(11, 19), (14, 15), (16, 16), (12, 24), (10, 26)], "K")
    line(g, 27, 10, 17, 17, "K"); line(g, 27, 12, 21, 17, "K")
    # the brows: thick, sloping hard up to the middle — the hannya's anguish
    poly(g, [(10, 24), (18, 19), (25, 14), (27, 15), (27, 17), (19, 22), (11, 26)], "K")
    # the eyes: large and glaring, all gold (open), a bold upper lid, the outer corners high
    poly(g, [(12, 27), (16, 24), (22, 24), (25, 27), (22, 31), (15, 31)], "G")
    poly(g, [(12, 27), (16, 24), (22, 24), (25, 27), (24, 27), (21, 25), (16, 25), (13, 28)], "K")
    line(g, 15, 31, 22, 31, "K")
    # the nose: a short bridge, wide flared nostrils
    line(g, 26, 27, 25, 31, "K"); poly(g, [(21, 33), (24, 31), (27, 32), (27, 34), (22, 35)], "K")
    # the folds of the grimace, from the nostrils to the mouth's corners
    line(g, 20, 32, 11, 38, "K")
    # the mouth: wide open, lacquer inside, gold lips; a band of teeth above, a long fang at each
    # corner above and a shorter one below
    poly(g, [(28, 37), (15, 37), (10, 39), (12, 44), (17, 48), (28, 49)], "D")
    line(g, 10, 39, 15, 36, "G"); line(g, 15, 36, 28, 36, "G"); line(g, 12, 44, 17, 49, "G"); line(g, 17, 49, 28, 50, "G")
    poly(g, [(16, 37), (28, 37), (28, 39), (16, 39)], "W")
    poly(g, [(12, 38), (15, 38), (14, 45), (13, 45)], "W")
    poly(g, [(17, 48), (20, 48), (18, 43), (17, 43)], "W")
    # the chin's crease
    line(g, 23, 52, 28, 52, "K")
    g = outline(g, "WG", "K")
    return mirror(g)

art = hannya()
open(sys.argv[1], "w").write("\n".join(art) + "\n")
ink = {"K": (17, 19, 20), "W": (241, 225, 180), "G": (226, 181, 64), "D": (130, 36, 31), ".": None}
im = Image.new("RGB", (W, H), (24, 23, 21))
for y, r in enumerate(art):
    for x, c in enumerate(r):
        if ink[c]: im.putpixel((x, y), ink[c])
big = im.resize((W * 6, H * 6), Image.NEAREST)
out = Image.new("RGB", (W * 6 + W + 30, H * 6 + 20), (24, 23, 21))
out.paste(big, (10, 10)); out.paste(im, (W * 6 + 20, 10))
out.save(sys.argv[2])


def tennin():
    g = blank()
    # the nimbus: a gold ring behind the head
    ell(g, 28, 25, 26, 25, "G", ring=0.84)
    # the hair: a high bun pinned at the top, long hair falling either side of the face
    ell(g, 28, 7, 6, 5, "K")
    poly(g, [(28, 10), (20, 11), (15, 16), (12, 24), (11, 34), (12, 44), (15, 50), (19, 50), (17, 40), (17, 26), (21, 17), (28, 15)], "K")
    line(g, 22, 4, 26, 2, "G"); line(g, 26, 2, 28, 2, "G")                 # the pin through the bun
    # the face: a calm oval, from the hairline to a soft chin
    poly(g, [(28, 14), (22, 16), (18, 21), (17, 28), (18, 35), (21, 41), (25, 45), (28, 46)], "W")
    # the brows: thin, gently arched
    line(g, 19, 23, 21, 22, "K"); line(g, 21, 22, 25, 22, "K")
    # the urna: the mark between the brows
    put(g, 27, 20, "D"); put(g, 27, 21, "D")
    # the eyes: open (her panel is open), almond, gold irises
    line(g, 19, 27, 21, 25, "K"); line(g, 21, 25, 25, 25, "K"); line(g, 25, 25, 26, 26, "K")
    put(g, 22, 26, "G"); put(g, 23, 26, "G"); put(g, 22, 27, "G"); put(g, 23, 27, "K")
    line(g, 20, 28, 25, 28, "K")
    # the nose: the faintest — two nostrils
    put(g, 26, 34, "K")
    # the smile: a little lacquer mouth, its corners lifted
    line(g, 23, 38, 24, 39, "D"); line(g, 24, 39, 28, 39, "D"); line(g, 25, 40, 28, 40, "D")
    # the neck and the robe's gold-edged collar
    poly(g, [(28, 45), (24, 45), (23, 50), (28, 50)], "W")
    poly(g, [(28, 50), (21, 49), (13, 52), (9, 55), (28, 55)], "D")
    line(g, 21, 49, 28, 53, "G")
    g = outline(g, "W", "K")
    return mirror(g)


art2 = tennin()
open(sys.argv[1].replace("hannya", "tennin"), "w").write("\n".join(art2) + "\n")
ink2 = {"K": (17, 19, 20), "W": (248, 243, 216), "G": (226, 181, 64), "D": (130, 36, 31), ".": None}
im2 = Image.new("RGB", (W, H), (232, 227, 194))
for y, r in enumerate(art2):
    for x, c in enumerate(r):
        if ink2[c]: im2.putpixel((x, y), ink2[c])
big2 = im2.resize((W * 6, H * 6), Image.NEAREST)
out2 = Image.new("RGB", (W * 6 + W + 30, H * 6 + 20), (232, 227, 194))
out2.paste(big2, (10, 10)); out2.paste(im2, (W * 6 + 20, 10))
out2.save(sys.argv[2].replace("hannya", "tennin"))
