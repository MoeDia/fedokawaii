#!/usr/bin/env python3
"""tools/build-samurai.py — the lock's small samurai (owner, 6 Nov: "a small retro Japanese pixel-art
samurai who reacts, super active, while he types the password"; dark a male samurai, light a gentle
female one, "super gentle feeling"). The parts are drawn by hand in art/samurai.txt; here they are
posed, a frame a line, each figure outlined whole. Sprites of the lock's grid: shown 3 × 3 on 1080p.

    python3 tools/build-samurai.py [--preview DIR]

What he reacts to carries no secret: a key's cut follows the order of the cuts, never the key.

Writes, for theme.sh to install, configs/home/.local/share/fedokawaii/MOOD/:
    lock-samurai.png   every frame in a grid of CELL_W × CELL_H cells, COLS across, transparent round it
    lock-samurai.txt   the cell, then per state: its frames and each one's time in ms; `loop` when it repeats
--preview DIR: a contact sheet per mood at 4 × 4 on its lock's tones, states in rows.
"""
import argparse
import importlib.util
import math
import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = ROOT / "art/samurai.txt"
OUT = ROOT / "configs/home/.local/share/fedokawaii"
_spec = importlib.util.spec_from_file_location("wada_palette", ROOT / "tools/wada-palette.py")
_wada = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wada)
_P = _wada.palette()[0]
D_, L_ = _P["dark"], _P["light"]

CELL_W, CELL_H = 72, 64
COLS = 8
GROUND = 61     # the row the soles stand on
HIP = 26        # the x the body stands on

# Outline K. Skin, straw and the plain cloth inks are the sprite's own: the palette has no skin; the
# rest by the palette's names, so a change of the seal's red reaches them.
INKS = {
    "m": {"K": D_["lo"], "R": D_["accent"], "H": D_["accent_hi"], "D": D_["accent_lo"], "Y": D_["yellow"],
          "F": "e9b98c", "f": "b98059", "W": D_["strong"], "N": "3a4f7a", "n": "27365a", "T": D_["gold"], "L": D_["accent_lo"], "b": D_["lo"],
          "S": "c8d2d6", "s": "7f8e96", "*": D_["byellow"], "z": D_["bblue"], "e": D_["strong"], "o": D_["flame"],
          "p": D_["strong"], "q": D_["flame"]},
    "f": {"K": "4a3a44", "H": "3b2c38", "h": "6d5868", "W": "fff8ee", "w": "e0d5d6", "R": "d9604c", "D": "b0453a",
          "F": "fbd9bb", "f": "dba98c", "B": "f4a79b", "Y": L_["gold"], "T": "c79f6a", "S": "c3d0da", "s": "8ea0af", "L": "6d3a3c", "b": None,
          "*": "ffffff", "z": "7fb8dc", "e": "f7b6c2", "o": "ec8ea3",
          "p": "f7b6c2", "q": "ec8ea3"},
}
LOOK = {"m": (D_["lo"], "2a2622"), "f": (L_["surface"], L_["key"])}  # the sheet's grounds

# eyes and mouth over the head as drawn: (x, y, ink); "skin" clears its eyes first
EYES = {"m": ((7, 10), (7, 11), (12, 10), (12, 11)), "f": ((6, 7), (7, 7), (7, 8), (11, 7), (12, 7), (11, 8))}
FACES = {
    "m": {
        "calm": [(9, 13, "f"), (10, 13, "f")],
        "blink": ["skin", (6, 11, "K"), (7, 11, "K"), (8, 11, "K"), (11, 11, "K"), (12, 11, "K"), (13, 11, "K"),
                  (9, 13, "f"), (10, 13, "f")],
        "wide": [(6, 10, "K"), (6, 11, "K"), (11, 10, "K"), (11, 11, "K"), (9, 13, "K")],
        "fierce": [(6, 9, "K"), (7, 9, "K"), (8, 10, "K"), (13, 9, "K"), (12, 9, "K"), (11, 10, "K"),
                   (9, 13, "f"), (10, 13, "f"), (11, 13, "f")],
        "shout": [(6, 9, "K"), (7, 9, "K"), (8, 10, "K"), (13, 9, "K"), (12, 9, "K"), (11, 10, "K"),
                  (9, 12, "K"), (10, 12, "K"), (11, 12, "K"), (9, 13, "D"), (10, 13, "R"), (11, 13, "K")],
        "wince": ["skin", (6, 10, "K"), (7, 11, "K"), (6, 12, "K"), (13, 10, "K"), (12, 11, "K"), (13, 12, "K"),
                  (9, 13, "K"), (10, 13, "K")],
        "joy": ["skin", (6, 11, "K"), (7, 10, "K"), (8, 11, "K"), (11, 11, "K"), (12, 10, "K"), (13, 11, "K"),
                (9, 12, "K"), (10, 12, "K"), (9, 13, "R"), (10, 13, "R")],
        "sad": [(6, 9, "f"), (8, 9, "K"), (11, 9, "K"), (13, 9, "f"), (9, 13, "K"), (10, 13, "K")],
    },
    "f": {
        "calm": [(8, 11, "f"), (9, 11, "f")],
        "blink": ["skin", (6, 8, "K"), (7, 8, "K"), (8, 8, "K"), (10, 8, "K"), (11, 8, "K"), (12, 8, "K"),
                  (8, 11, "f"), (9, 11, "f")],
        "wide": [(6, 8, "K"), (12, 8, "K"), (9, 11, "R")],
        "fierce": [(6, 6, "H"), (8, 7, "K"), (10, 7, "K"), (12, 6, "H"), (8, 11, "R"), (9, 11, "R")],
        "shout": [(8, 7, "K"), (10, 7, "K"), (8, 11, "R"), (9, 11, "R"), (8, 10, "D"), (9, 10, "D")],
        "wince": ["skin", (6, 7, "K"), (7, 8, "K"), (8, 7, "K"), (10, 7, "K"), (11, 8, "K"), (12, 7, "K"),
                  (8, 11, "f"), (9, 11, "f")],
        "joy": ["skin", (6, 8, "K"), (7, 7, "K"), (8, 8, "K"), (10, 8, "K"), (11, 7, "K"), (12, 8, "K"),
                (8, 11, "R"), (9, 11, "R")],
        "sad": [(6, 6, "H"), (12, 6, "H"), (8, 11, "K"), (9, 11, "K"), (7, 9, "z")],
    },
}


def sheet():
    parts, name, rows, want = {}, None, [], None

    def close():
        if name is None:
            return
        if len(rows) != want[1] or any(len(r) != want[0] for r in rows):
            bad = [i for i, r in enumerate(rows) if len(r) != want[0]]
            raise SystemExit(f"{SHEET.name}: {name} is not {want[0]} x {want[1]}: {len(rows)} rows, wrong: {bad}")
        parts[name] = rows

    for line in SHEET.read_text().splitlines():
        if line.startswith("@"):
            close()
            head = line[1:].split()
            name, want, rows = head[0], (int(head[1]), int(head[2])), []
        elif line and not line.startswith("#") and name is not None:
            rows.append(line)
    close()
    return parts


PARTS = sheet()


class Cell:
    """A frame's two layers of letters: the figure (outlined whole) and what flies over it (not)."""

    def __init__(self):
        self.body = {}
        self.fx = {}

    def part(self, rows, x, y, layer=None):
        layer = self.body if layer is None else layer
        for j, row in enumerate(rows):
            for i, c in enumerate(row):
                if c != ".":
                    layer[(x + i, y + j)] = c

    def line(self, x0, y0, x1, y1, ink, layer=None):
        layer = self.body if layer is None else layer
        for x, y in line_points(x0, y0, x1, y1):
            layer[(x, y)] = ink

    def outlined(self):
        out = dict(self.body)
        for soft in (True, False):      # blade and scabbard a softer line, the figure's over it
            for (x, y), c in self.body.items():
                if (c in "SsL") != soft:
                    continue
                for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    p = (x + d[0], y + d[1])
                    if p not in self.body:
                        out[p] = "b" if soft else "K"
        out.update(self.fx)
        return out


def line_points(x0, y0, x1, y1):
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    e, pts = dx + dy, []
    while True:
        pts.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return pts
        e2 = 2 * e
        if e2 >= dy:
            e += dy
            x0 += sx
        if e2 <= dx:
            e += dx
            y0 += sy


def unit(deg, n):
    return round(math.cos(math.radians(deg)) * n), round(math.sin(math.radians(deg)) * n)


def draw_sword(c, hx, hy, deg, kind):
    """Hilt through the hand, the guard, the blade: bright edge on steel, the same at every angle."""
    length = 20 if kind == "m" else 19
    tx, ty = unit(deg + 180, 4)
    wrap = "D" if kind == "m" else "H"
    c.line(hx, hy, hx + tx, hy + ty, wrap)
    gx, gy = unit(deg, 2)
    px, py = unit(deg + 90, 1)
    for k in (-1, 0, 1):
        c.body[(hx + gx + px * k, hy + gy + py * k)] = "Y"
    ex, ey = unit(deg, length)
    while hy + ey > GROUND:     # a blade pointing down stops in the ground, its tip buried
        length -= 1
        ex, ey = unit(deg, length)
    bx, by = (0, 1) if abs(ex) >= abs(ey) else (1, 0)
    c.line(hx + gx + bx, hy + gy + by, hx + ex + bx, hy + ey + by, "s")
    c.line(hx + gx, hy + gy, hx + ex, hy + ey, "S")
    return hx + ex, hy + ey


def draw_sheath(c, hipx, hipy, kind):
    """At his side, the mouth forward, the tip behind him, the hilt ready under the hand."""
    c.line(hipx + 4, hipy, hipx - 14, hipy + 5, "L")
    c.line(hipx + 5, hipy, hipx + 9, hipy - 1, "W" if kind == "m" else "R")
    c.body[(hipx + 5, hipy + 1)] = "Y"


def draw_arm(c, sx, sy, hx, hy, kind, sleeve):
    mx, my = (sx + hx) // 2, (sy + hy) // 2 + 1
    for (x0, y0, x1, y1) in ((sx, sy, mx, my), (mx, my, hx, hy)):
        for k in (0, 1):
            c.line(x0, y0 + k, x1, y1 + k, sleeve)
            c.line(x0 + 1, y0 + k, x1 + 1, y1 + k, sleeve)
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        c.body[(hx + dx, hy + dy)] = "F"


def fx_smear(c, cx, cy, a0, a1, r):
    """A cut's arc: three rows at its thickest, thin at both ends, whole pixels."""
    if a1 < a0:
        a0, a1 = a1, a0
    n = int((a1 - a0) * r / 25) + 2
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        w = 3.4 * math.sin(math.pi * t) ** .8     # a crescent, its outer edge on the blade's tip
        for k in range(int(round(w)) + 1):
            p = (round(cx + (r - k) * math.cos(a)), round(cy + (r - k) * math.sin(a)))
            ink = "e" if k <= 1 else "o"
            if p not in c.fx or ink == "e":
                c.fx[p] = ink


def fx_star(c, x, y, big=False, ink="*"):
    c.fx[(x, y)] = ink
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c.fx[(x + dx, y + dy)] = ink
    if big:
        for dx, dy in ((2, 0), (-2, 0), (0, 2), (0, -2)):
            c.fx[(x + dx, y + dy)] = ink


def fx_petal(c, x, y):
    c.part(("pp.", "pqp", ".qq"), x, y, c.fx)


def fx_drop(c, x, y):
    c.part((".z.", "zzz", ".z."), x, y, c.fx)


def fx_bang(c, x, y):
    c.part(("YY", "YY", "YY", "YY", "..", "YY"), x, y, c.fx)


def fx_dizzy(c, x, y):
    fx_star(c, x, y)
    fx_star(c, x + 11, y + 2)


def frame(kind, legs="stand", up=0, dx=0, lean=0, nod=0, shake=0, face="calm", hand=None, deg=None, off=None,
          sheath=False, tail=0, fx=()):
    """One frame. up: the whole figure off the ground; lean: the top half; nod: the head into the chest.
    hand: the sword arm's hand from the shoulder; off: the other's; deg: the blade (0 right, -90 up)."""
    c = Cell()
    legrows = PARTS[f"{kind}.{legs}"]
    torso = PARTS[f"{kind}.torso"]
    head = list(map(list, PARTS[f"{kind}.head"]))
    cx = HIP + dx
    legx = cx - len(legrows[0]) // 2
    legy = GROUND - up - len(legrows)
    tx = cx - len(torso[0]) // 2 + lean
    ty = legy - len(torso) + 2
    hx = tx + len(torso[0]) // 2 - len(head[0]) // 2 + 1 + lean + shake
    hy = ty - len(head) + 1 + nod
    shx, shy = tx + len(torso[0]) - 5, ty + 1
    bhx, bhy = tx + 2, ty + 1
    sleeve = "N" if kind == "m" else "W"

    if kind == "f":
        c.part(PARTS[f"f.tail{tail}"], hx - 6, hy + 2)
    if off:
        draw_arm(c, bhx, bhy, bhx + off[0], bhy + off[1], kind, "n" if kind == "m" else "w")
    hand = hand or (3, 7)
    fhx, fhy = shx + hand[0], shy + hand[1]
    tip = None
    if deg is not None and deg < -70:       # raised or thrown back: behind the head, never through it
        tip = draw_sword(c, fhx, fhy, deg, kind)
    c.part(legrows, legx, legy)
    if sheath or deg is not None:
        draw_sheath(c, tx + len(torso[0]) // 2 - 1, ty + 6, kind)
    c.part(torso, tx, ty)
    for spec in FACES[kind][face]:
        if spec == "skin":
            for x, y in EYES[kind]:
                head[y][x] = "F"
    for spec in FACES[kind][face]:
        if spec != "skin":
            x, y, ink = spec
            head[y][x] = ink
    c.part(["".join(r) for r in head], hx, hy)
    if deg is not None and tip is None:
        tip = draw_sword(c, fhx, fhy, deg, kind)
    draw_arm(c, shx, shy, fhx, fhy, kind, sleeve)
    if kind == "m":
        c.part(PARTS["m.sode"], shx - 2, shy - 2)
    for f in fx:
        f(c, tip, (hx, hy), (fhx, fhy))
    return c.outlined()


# what flies: functions of (cell, blade tip, head's corner, hand)
def smear(a0, a1, r=None):
    return lambda c, t, h, p: fx_smear(c, p[0], p[1], a0, a1, r or 20)


def spark(dx=0, dy=0, big=False):
    return lambda c, t, h, p: fx_star(c, t[0] + dx, t[1] + dy, big)


def petals(*at):
    return lambda c, t, h, p: [fx_petal(c, x, y + 8) for x, y in at]


def stars(*at):
    return lambda c, t, h, p: [fx_star(c, x, y + 8, b) for x, y, b in at]


def bang(c, t, h, p):
    fx_bang(c, h[0] + 8, h[1] - 8)


def drop(dx, dy):
    return lambda c, t, h, p: fx_drop(c, h[0] + dx, h[1] + dy)


def swirl(c, t, h, p):
    fx_dizzy(c, h[0] + 3, h[1] - 3)


READY = dict(legs="stand", hand=(5, 2), deg=-48, off=(6, 7), face="fierce")
GENTLE = dict(legs="stand", hand=(4, 4), deg=-30, off=(5, 8), face="calm")


def states(k):
    """state: (loop, [(frame, ms) …]): a state ends in its last frame; the module goes on from there."""
    def f(**a):
        return frame(k, **a)

    if k == "m":
        def ready(**a):
            return f(**{**READY, **a})

        return {
            "idle": (True, [(f(sheath=True), 900), (f(sheath=True, nod=1), 700), (f(sheath=True), 900),
                            (f(sheath=True, face="blink"), 120)]),
            "start": (False, [(f(sheath=True, face="wide", up=2, fx=(bang,)), 90),
                              (f(legs="crouch", sheath=True, face="fierce", hand=(5, 8)), 70),
                              (f(legs="lunge", hand=(8, 3), deg=-14, face="shout", lean=1, fx=(smear(-70, -14),)), 60),
                              (ready(), 70)]),
            "ready": (True, [(ready(), 500), (ready(nod=1, hand=(5, 3)), 500)]),
            "key0": (False, [(ready(hand=(1, -6), deg=-104, lean=-1), 30),
                             (f(legs="lunge", hand=(10, 3), deg=14, off=(8, 8), face="shout", lean=2,
                                fx=(smear(-105, 14), spark(1, 0))), 45),
                             (ready(hand=(6, 3), deg=-30), 40)]),
            "key1": (False, [(ready(hand=(4, 9), deg=38, lean=-1), 30),
                             (f(legs="lunge", hand=(9, -2), deg=-68, off=(8, 8), face="shout", lean=2,
                                fx=(smear(-68, 38), spark(0, -1))), 45),
                             (ready(hand=(6, 1), deg=-58), 40)]),
            "key2": (False, [(ready(hand=(-1, 3), deg=0, lean=-2), 30),
                             (f(legs="lunge", hand=(12, 2), deg=0, off=(6, 8), face="shout", lean=3,
                                fx=(spark(2, 0, True),)), 45),
                             (ready(hand=(6, 3), deg=-22), 40)]),
            "delete": (False, [(f(legs="back", dx=-2, lean=-1, hand=(3, -5), deg=-118, off=(5, 2), face="wince",
                                  fx=(drop(16, -1),)), 60),
                               (f(legs="back", dx=-4, lean=-2, hand=(5, 7), deg=44, off=(5, 8), face="sad",
                                  fx=(drop(17, 2),)), 70),
                               (ready(dx=-2), 60)]),
            "right": (False, [(f(legs="crouch", hand=(5, 2), deg=-48, face="wide"), 70),
                              (f(legs="jump", up=5, hand=(4, -9), deg=-86, off=(-3, -7), face="joy", fx=(spark(0, -1),)), 70),
                              (f(legs="jump", up=9, hand=(4, -9), deg=-86, off=(-3, -7), face="joy",
                                 fx=(spark(0, -1, True), stars((8, 12, False), (49, 18, False)))), 130),
                              (f(legs="crouch", hand=(4, -8), deg=-86, off=(-3, -5), face="joy", fx=(stars((10, 22, False), (50, 28, False)),)), 80),
                              (f(legs="stand", hand=(5, 7), deg=170, face="calm"), 80),
                              (f(legs="stand", sheath=True, nod=2, lean=2, face="blink", fx=(stars((47, 22, False),),)), 280)]),
            "wrong": (False, [(f(legs="back", dx=-3, lean=-2, hand=(0, -7), deg=-132, off=(-2, 5), face="wince",
                                 fx=(spark(0, 0, True),)), 70),
                              (f(legs="back", dx=-5, lean=-3, up=1, hand=(-2, -6), deg=-150, off=(-3, 5), face="wide",
                                 fx=(swirl, drop(17, 2))), 110),
                              (f(legs="kneel", dx=-4, hand=(6, 6), deg=86, off=(-1, 8), face="sad", nod=1, fx=(swirl,)), 150),
                              (f(legs="kneel", dx=-4, hand=(6, 6), deg=86, off=(-1, 8), face="sad", nod=2, shake=-1,
                                 fx=(drop(1, 4),)), 150),
                              (f(legs="kneel", dx=-4, hand=(6, 6), deg=86, off=(-1, 8), face="sad", nod=2, shake=1,
                                 fx=(drop(1, 7),)), 150),
                              (f(legs="crouch", dx=-2, hand=(5, 3), deg=-40, off=(6, 7), face="fierce"), 90)]),
        }
    def ready(**a):
        return f(**{**GENTLE, **a})

    return {
        "idle": (True, [(f(sheath=True), 1000), (f(sheath=True, nod=1, tail=1), 800), (f(sheath=True), 1000),
                        (f(sheath=True, face="blink"), 140)]),
        "start": (False, [(f(sheath=True, face="wide", up=1, tail=1, fx=(petals((42, 8)),)), 110),
                          (f(legs="crouch", sheath=True, face="joy", hand=(5, 7), fx=(petals((44, 14)),)), 90),
                          (f(hand=(7, 4), deg=-14, off=(4, 8), face="joy", tail=1, fx=(smear(-60, -14, 19),)), 90),
                          (ready(), 90)]),
        "ready": (True, [(ready(), 650), (ready(nod=1, tail=1), 650)]),
        "key0": (False, [(ready(hand=(2, -3), deg=-76, tail=1), 35),
                         (f(legs="lunge", hand=(8, 4), deg=8, off=(6, 8), face="shout", lean=1, fx=(smear(-76, 8, 19), petals((54, 22)))), 55),
                         (ready(tail=1), 45)]),
        "key1": (False, [(ready(hand=(4, 8), deg=32, tail=1), 35),
                         (f(legs="lunge", hand=(8, 0), deg=-52, off=(6, 8), face="shout", lean=1, fx=(smear(-52, 32, 19), petals((52, 12)))), 55),
                         (ready(tail=1), 45)]),
        "key2": (False, [(ready(hand=(0, 4), deg=-6, tail=1), 35),
                         (f(legs="lunge", hand=(10, 3), deg=-6, off=(6, 8), face="fierce", lean=2, fx=(petals((56, 16), (50, 26)),)), 55),
                         (ready(tail=1), 45)]),
        "delete": (False, [(f(legs="back", dx=-1, hand=(3, 6), deg=30, off=(6, -2), face="wide", tail=1), 80),
                           (f(legs="back", dx=-3, lean=-1, hand=(3, 7), deg=40, off=(6, -3), face="wince"), 90),
                           (ready(dx=-1, face="blink"), 80)]),
        "right": (False, [(f(hand=(5, 7), deg=170, off=(6, 5), face="wide"), 110),
                          (f(sheath=True, hand=(6, 3), off=(9, 2), face="joy", up=1, tail=1, fx=(petals((10, 14), (46, 8)),)), 130),
                          (f(sheath=True, hand=(6, 5), off=(9, 5), face="joy", lean=2, nod=2, fx=(petals((13, 20), (47, 14), (30, 4)),)), 150),
                          (f(legs="crouch", sheath=True, hand=(6, 6), off=(9, 6), face="blink", lean=4, nod=4, fx=(petals((14, 28), (48, 22), (28, 10)),)), 320),
                          (f(sheath=True, hand=(6, 5), off=(9, 5), face="joy", lean=2, nod=2, tail=1, fx=(petals((16, 36), (50, 30), (30, 18)),)), 150),
                          (f(sheath=True, hand=(6, -8), face="joy", tail=1, fx=(petals((18, 44), (52, 38), (32, 26)),)), 280)]),
        "wrong": (False, [(f(legs="back", dx=-1, hand=(3, 6), deg=32, off=(7, -3), face="wide", tail=1), 110),
                          (f(legs="back", dx=-2, hand=(3, 7), deg=44, off=(7, -3), face="sad", nod=1), 170),
                          (f(legs="kneel", dx=-2, hand=(5, 6), deg=70, off=(6, 7), face="sad", nod=2, shake=-1, fx=(drop(5, 13),)), 170),
                          (f(legs="kneel", dx=-2, hand=(5, 6), deg=70, off=(6, 7), face="sad", nod=2, shake=1, tail=1, fx=(drop(5, 16),)), 170),
                          (f(legs="crouch", dx=-1, hand=(5, 4), deg=-20, off=(5, 2), face="blink"), 130),
                          (ready(hand=(4, 2), off=(8, 1), face="joy", tail=1), 170)]),
    }


def picture(cells, ink):
    im = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    for (x, y), c in cells.items():
        if not (0 <= x < CELL_W and 0 <= y < CELL_H):
            raise SystemExit(f"a pixel off the cell at {x},{y}")
        h = ink[c]
        if h is None:       # her blade and scabbard have no line at all: slim, gentle
            continue
        im.putpixel((x, y), (int(h[:2], 16), int(h[2:4], 16), int(h[4:], 16), 255))
    return im


def preview(kind, st, d):
    n = max(len(v[1]) for v in st.values())
    sc = 4
    pad = 2
    a, b = LOOK[kind]
    im = Image.new("RGB", ((CELL_W * sc + pad) * n, (CELL_H * sc + pad) * len(st)), f"#{a}")
    ink = INKS[kind]
    for j, (_name, (_loop, frames)) in enumerate(st.items()):
        for i, (cells, _ms) in enumerate(frames):
            cell = picture(cells, ink)
            ground = Image.new("RGBA", (CELL_W, CELL_H), f"#{b}")
            ground.alpha_composite(cell)
            im.paste(ground.resize((CELL_W * sc, CELL_H * sc), Image.NEAREST).convert("RGB"),
                     (i * (CELL_W * sc + pad), j * (CELL_H * sc + pad)))
    d.mkdir(parents=True, exist_ok=True)
    im.save(d / f"samurai-{kind}.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", type=pathlib.Path)
    args = ap.parse_args()
    for kind, mood in (("m", "dark"), ("f", "light")):
        st = states(kind)
        total = sum(len(v[1]) for v in st.values())
        rows = math.ceil(total / COLS)
        strip = Image.new("RGBA", (CELL_W * COLS, CELL_H * rows), (0, 0, 0, 0))
        lines = [f"cell {CELL_W} {CELL_H} {COLS}"]
        at = 0
        for name, (loop, frames) in st.items():
            words = []
            for cells, ms in frames:
                strip.alpha_composite(picture(cells, INKS[kind]), ((at % COLS) * CELL_W, (at // COLS) * CELL_H))
                words.append(f"{at}:{ms}")
                at += 1
            lines.append(" ".join([name, "loop" if loop else "once"] + words))
        if args.preview:
            preview(kind, st, args.preview)
        else:
            dest = OUT / mood
            strip.save(dest / "lock-samurai.png", optimize=True)
            (dest / "lock-samurai.txt").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
