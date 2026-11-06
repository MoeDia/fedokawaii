#!/usr/bin/env python3
"""tools/build-lockmap.py — the walls behind the lock's samurai (owner, 6 Nov: "super pixel-arty, full,
very fun, a dense metroidvania-map style"; "4 distinct variants for dark AND 4 for light"). Each world is
a map laid out by hand below, a letter a room on a 16 × 10 grid, cut open like a doll's house; rooms join
by doors and ladders, the props are drawn by hand in art/lockmap.txt, and the corner's map is the world's
own rooms. Whole pixels on the lock's grid: 640 × 360, shown 3 × 3 on 1080p. No demon, no angel: those
stay on the wallpapers. Z is the samurai's room, the same in every world: its floor is STAGE_FLOOR.

    python3 tools/build-lockmap.py [--preview DIR]

Writes, for theme.sh to install, configs/home/.local/share/fedokawaii/MOOD/lock-map-NAME.png.
--preview DIR: a sheet of the 4 at 1 × per mood.
"""
import argparse
import pathlib
import random

import numpy as np
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "configs/home/.local/share/fedokawaii"
W, H = 640, 360
CW, CH = 40, 36
WALL, FLOOR = 4, 6    # a room's walls and floor, in pixels
STAGE_FLOOR = 9 * CH - FLOOR
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16

# The props' inks that every world shares; a world overrides what it needs in "ink".
INK = dict(K="1a1420", a="c98f52", b="96602f", c="643c22", s="b4b0a4", t="827e78", u="56525a",
           r="c8352b", R="ee6a48", y="c8962e", Y="f2d264", g="4d8a3c", G="86c057", w="f4ecd8", W="c4d8e4",
           m="aab4bc", n="5a6470", l="f08428", L="ffd860", p="e88aa0", P="f8bccb", e="4aa8d8", E="2a6ca0",
           o="f09030")

WORLDS = {
    "dark": {
        "shiro": dict(  # the castle at night, its catacombs under the hill
            rows=["       ^^       ",
                  "     ^^aa^^     ",
                  "  ^^^ bbcc ^^^  ",
                  "  dde ffgg hhi  ",
                  "^^dde jjkk lli^^",
                  "mmnnooppqqrrsstt",
                  "uuvvwZZZZZZxxyyA",
                  "uuBBwZZZZZZCCDDA",
                  "EEBBFZZZZZZGGDDH",
                  "IIIJJJKKKKLLLMMM"],
            sky=dict(bands=["0a0d24", "11183a", "1b2650", "2a3564"], moon=(120, 56, 26), stars=170, peaks="141a38"),
            rock=("brick", "33313f", "474555", "6d6b79", "26242f"), roof=("2c3a58", "3f5478", "5e789a"),
            backs=[("shoji", "4d4230", "2a2318"), ("plank", "3a2618", "2b1c12"), ("brick", "26283c", "1b1c2c"),
                   ("stone", "2f3044", "222334"), ("shoji", "574a2e", "2f2614"), ("plank", "4a1f1c", "361512")],
            stage=("asanoha", "1c1d30", "2a2c44"), banner=True,
            floor="chest chestopen lantern swords bonsai daruma barrel jar crate books kettle shrine cat skeleton ninja tanuki".split(),
            ceil="hanglamp bell bat hanglamp chain".split(), wall="scroll torch banner torch key coin".split(),
            bits=("wisp", 5)),
        "kozan": dict(  # the mine: tunnels, carts, crystals, a lake of glow far down
            rows=["   ##     ###   ",
                  "aaa##bbb##ccc#dd",
                  "#ee##bbb#fff##dd",
                  "#eeggg##hhh#iiii",
                  "jj#ggg#kkk##iiii",
                  "jjll###kkkmmm#nn",
                  "#oll#ZZZZZZ#mm#n",
                  "pooq#ZZZZZZ#rr#n",
                  "pqqq#ZZZZZZssrtt",
                  "uuuvvvwwwwwxxxxx"],
            cave=True,
            sky=dict(bands=["10121e", "171a2c", "252036"], stars=60),
            rock=("strata", "2a2230", "3a2e3c", "6a8a4a", "1c1622"), roof=("2c3a58", "3f5478", "5e789a"),
            backs=[("cave", "1b1826", "241f30"), ("cave", "201a22", "2c2428"), ("cave", "14202a", "1c2c36"),
                   ("plank", "2f2016", "241810"), ("cave", "261826", "33203a")],
            stage=("stone", "15141f", "211f2e"), pool=("e", "1a6a98", "50d0e0", .22),
            floor="cart crystal crystal mushroom barrel crate jar slime lantern anvil chest skeleton mushroom frog".split(),
            ceil="stalactite stalactite bat stalactite hanglamp chain".split(), wall="torch coin key crystal".split(),
            bits=("coin", 7), glow="crystal"),
        "suichu": dict(  # the temple that sank: all of it under water, the moon somewhere above
            rows=["                ",
                  "    ^^^    ^^   ",
                  "    aaa    bb   ",
                  " ^^ ccc  ddbb   ",
                  " ee ccc  dd  ff ",
                  "geehhiijjkkllff ",
                  "gmmnnZZZZZZoopp#",
                  "#qqnnZZZZZZrrpp#",
                  "#qqssZZZZZZrrtt#",
                  "##uuuuvvvvwwww##"],
            sky=dict(bands=["0c4a6a", "0a3c5c", "08304e", "062640", "051c32"], rays=9, seabed="0f2c3c"),
            rock=("stone", "1d4450", "2a5c66", "4e9a8a", "10303c"), roof=("104a58", "1a6a72", "38a08c"),
            backs=[("stone", "0e3448", "0a2a3c"), ("shoji", "24505a", "0e3440"), ("brick", "12405a", "0c304a"),
                   ("plank", "1e4048", "163238"), ("stone", "164a50", "103a40")],
            stage=("seigaiha", "07243a", "0e3650"), pool=("e", "0c5a7a", "3cb0c8", .25), ink=dict(l="50e0c0", L="d0fff0"),
            floor="seaweed seaweed coral anchor chest jar shrine coral skeleton crate seaweed cat".split(),
            ceil="seaweed bell hanglamp chain".split(), wall="koi koi scroll coin koi".split(),
            bits=("koi", 11), dust="bubble"),
        "kaji": dict(  # the sword forge in the volcano: chains, furnaces, a river of fire at the foot
            rows=["####aaaa##bbbb##",
                  "cc##aaaa##bbbbdd",
                  "cceeeff#ggg#hhdd",
                  "##eeeff#ggg#hhii",
                  "jjjkk##lll##mmii",
                  "jjjkk#nnnnoommpp",
                  "qqrrrZZZZZZssspp",
                  "qqrrrZZZZZZssstt",
                  "uuvvvZZZZZZwwwtt",
                  "xxxxxxxxxxxxxxxx"],
            cave=True,
            sky=dict(bands=["1c0a0c"]),
            rock=("strata", "2c1412", "42201a", "c8602a", "1c0c0c"), roof=("3a1816", "5a241c", "a04024"),
            backs=[("brick", "3a1a14", "2a120e"), ("stone", "341614", "260e0e"), ("cave", "401c12", "2e1410"),
                   ("plank", "38201a", "281612"), ("brick", "4a2212", "361808")],
            stage=("stone", "1f0e0e", "32170f"), pool=("l", "e84a18", "ffd040", .35),
            floor="anvil cauldron swords sword barrel crate chest sword kettle cart shrine jar".split(),
            ceil="chain chain gear hanglamp chain".split(), wall="torch gear sword banner torch".split(),
            bits=("wisp", 4), dust="ember", lastpool=True),
    },
    "light": {
        "haru": dict(  # spring: a town climbing a hill under cherry trees
            rows=["                ",
                  "            ^^^ ",
                  " %%      ^^^aaa%",
                  "%%%%  ^^^bbbaaa%",
                  "%%%%^^cccbbbdd%%",
                  "^^^^eefffggddhhh",
                  "iiijjZZZZZZkkkhh",
                  "iiillZZZZZZmmnnn",
                  "oopllZZZZZZmmnnn",
                  "qqqqrrrrssssttt#"],
            ink=dict(K="4a3a44"),
            sky=dict(bands=["bfe4f2", "d4eef2", "f2f0e0", "fce4d8"], sun=(90, 44, 20), peaks="c8dce6", clouds=7),
            rock=("earth", "c9a98a", "dcc0a0", "a6cf78", "8f7360"), roof=("6a7a96", "8a9cb6", "b4c4d4"),
            backs=[("shoji", "fff6e4", "c4a884"), ("plank", "e8c8a0", "d4b086"), ("shoji", "fdeee0", "d0a890"),
                   ("wash", "fbe0dc", "f4ccd0"), ("plank", "dcc0a4", "c8a88c")],
            stage=("asanoha", "fff8ee", "f8e4da"), canopy=("e88aa0", "f8bccb", "fde2e6"),
            floor="bonsai daruma lantern chest barrel jar kettle books cat tanuki tree bucket frog shrine".split(),
            ceil="hanglamp bell bell hanglamp".split(), wall="scroll kite heart scroll coin".split(),
            bits=("kite", 3), dust="petal"),
        "kumo": dict(  # the islands in the clouds: pavilions, kites, a long rainbow
            rows=["     ^^^        ",
                  "  ^^ aaa   ^^^  ",
                  "  bb aaa%  ccc  ",
                  " %bb%   %%%ccc% ",
                  "  ^^  ^^ee^^ ^^ ",
                  "  dd%%ffffgg%hh%",
                  "iidd%ZZZZZZ%kkll",
                  "iijj%ZZZZZZ%kkll",
                  "iijj%ZZZZZZ%%%%%",
                  "%%%%%%%%%%%%%%%%"],
            ink=dict(K="3e4a6a"),
            sky=dict(bands=["8fd0f4", "aee0f8", "c9ecfa", "e2f5fb"], rainbow=True, clouds=14),
            rock=("cloud", "e8eff8", "ffffff", "ffffff", "b4c4dc"), roof=("c8524a", "e27860", "f4ac8c"),
            backs=[("shoji", "fffaf0", "d8c4a4"), ("wash", "fff0d8", "fde4c4"), ("plank", "f0d8b0", "e0c498"),
                   ("wash", "e4f0fc", "d4e6f8"), ("shoji", "fff4ec", "e4b8a4")],
            stage=("seigaiha", "fffdf6", "e6f0fa"), canopy=("c4d4ea", "f0f6fc", "ffffff"),
            floor="kettle bonsai lantern chest books daruma jar cat shrine bell torii".split(),
            ceil="bell hanglamp bell".split(), wall="kite scroll heart kite coin".split(),
            bits=("kite", 6), dust="spark"),
        "yu": dict(  # the hot-spring mountain: pools, steam, falling water, monkeys
            rows=["       ^^       ",
                  "      ^aa^      ",
                  "     ##bb##     ",
                  "    ccc##ddd    ",
                  "  ##ccceeeddd## ",
                  " ffff#eee#gghhh ",
                  "#fiiiZZZZZZgghh#",
                  "jjiiiZZZZZZkkkll",
                  "jjmmmZZZZZZkkkll",
                  "nnnnooooopppppqq"],
            ink=dict(K="3e4a3e"),
            sky=dict(bands=["cfe8d8", "dff0dc", "f0f4dc", "faf0d4"], peaks="b6d4bc", clouds=6, sun=(560, 40, 16)),
            rock=("strata", "9ab08e", "b0c4a0", "8cc060", "708868"), roof=("5a6a58", "7a8c74", "a4b49a"),
            backs=[("plank", "e8d4ac", "d8c094"), ("shoji", "fbf4e0", "b49c78"), ("wash", "d8f0ec", "c4e8e4"),
                   ("stone", "d4dcc4", "c0caae"), ("plank", "dcc8a0", "ccb48c")],
            stage=("seigaiha", "f8fbee", "e2eeda"), pool=("e", "6cc8d8", "d0f4f4", .5), steam=True,
            floor="monkey bucket bamboo bamboo frog lantern bonsai jar kettle monkey tanuki shrine".split(),
            ceil="hanglamp bell hanglamp".split(), wall="scroll heart coin scroll".split(),
            bits=("frog", 0), dust="steam", falls=3),
        "yuki": dict(  # the snow shrine on the peaks: ice caves, red gates, soft falling snow
            rows=["  ^^        ^^^ ",
                  "  aa   ^^   bbb ",
                  "##aa## cc ##bbb#",
                  "#dd#####c##eee##",
                  "#ddfff#gggg#eehh",
                  "iifff##gggg##hhh",
                  "iijjkZZZZZZllhhh",
                  "mmjjkZZZZZZllnnn",
                  "mmoooZZZZZZpppnn",
                  "qqqqqqrrrrrrssss"],
            ink=dict(K="42506a"), cave=True,
            sky=dict(bands=["c8dcec", "d8e6f2", "e6eff6", "f2f6fa"], peaks="b4c8dc", clouds=4),
            rock=("snow", "c4d6e8", "d0e0ee", "ffffff", "8ea4bc"), roof=("a84038", "c85a4c", "fafcff"),
            backs=[("cave", "e0ecf6", "d0e2f0"), ("shoji", "fbf8f0", "a89c94"), ("cave", "d4e6f4", "c4dcee"),
                   ("plank", "dcc8b4", "c8b4a0"), ("wash", "f0f4fa", "e4ecf6")],
            stage=("asanoha", "fbfdff", "e4eef8"), pool=("e", "a4d4f0", "e8f8ff", .22),
            floor="snowman torii lantern crystal chest jar bonsai cat kettle shrine snowman bucket".split(),
            ceil="stalactite hanglamp stalactite bell".split(), wall="scroll coin heart key".split(),
            bits=("kite", 2), dust="snow"),
    },
}


def binary(m, n, grow):
    # a mask grown or shrunk n pixels, a diamond at a time
    for _ in range(n):
        near = (np.roll(m, 1, 0), np.roll(m, -1, 0), np.roll(m, 1, 1), np.roll(m, -1, 1))
        for other in near:
            m = (m | other) if grow else (m & other)
    return m


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.uint8)


def sprites():
    out, name = {}, None
    for line in (ROOT / "art/lockmap.txt").read_text().splitlines():
        if line.startswith("#"):
            continue
        if line.startswith("@"):
            name = line[1:]
            out[name] = []
        elif line:
            out[name].append(line)
    return out


class Map:
    def __init__(self, world, name):
        self.w, self.name = world, name
        self.rng = random.Random(name)
        self.nr = np.random.default_rng(sum(map(ord, name)))
        self.ink = {**INK, **world.get("ink", {})}
        self.rows = world["rows"]
        assert len(self.rows) == 10 and all(len(r) == 16 for r in self.rows), name
        assert all(self.rows[r][c] == "Z" for r in (6, 7, 8) for c in range(5, 11)), name
        self.img = np.zeros((H, W, 3), np.uint8)
        self.room = np.full((H, W), "#", dtype="<U1")   # which room each pixel is; # solid, " " open
        self.busy = np.zeros((H, W), bool)              # taken by a prop
        self.lights = []
        self.sprites = sprites()

    def cell(self, c, r):
        return self.rows[r][c] if 0 <= c < 16 and 0 <= r < 10 else None

    def isroom(self, ch):
        return ch is not None and ch not in " #^%"

    # the sky behind everything: bands in a Bayer step, what hangs in it
    def sky(self):
        s, bands = self.w["sky"], self.w["sky"]["bands"]
        grid = np.indices((H, W))
        t = grid[0] / H * max(len(bands) - 1, 1)
        low = np.floor(t).astype(int)
        high = np.minimum(low + 1, len(bands) - 1)
        step = (t - low) > BAYER[grid[0] % 4, grid[1] % 4]
        cols = np.array([rgb(b) for b in bands])
        self.img[:] = np.where(step[..., None], cols[high], cols[low])
        yy, xx = grid
        for key, tone in (("moon", ("f8f0cc", "d8cca0")), ("sun", ("fff4c4", "ffe49a"))):
            if key in s:
                x, y, rad = s[key]
                self.img[(xx - x) ** 2 + (yy - y) ** 2 < rad ** 2] = rgb(tone[0])
                halo = ((xx - x) ** 2 + (yy - y) ** 2 < (rad + 7) ** 2) & ((xx + yy) % 2 == 0)
                self.img[halo & ((xx - x) ** 2 + (yy - y) ** 2 >= rad ** 2)] = rgb(tone[1])
                if key == "moon":
                    for dx, dy, cr in ((-8, -5, 5), (6, 8, 7), (9, -10, 3)):
                        self.img[(xx - x - dx) ** 2 + (yy - y - dy) ** 2 < cr ** 2] = rgb(tone[1])
        for _ in range(s.get("stars", 0)):
            x, y = self.rng.randrange(W), self.rng.randrange(150)
            self.img[y, x] = rgb(self.rng.choice(["ffffff", "c8d4f4", "ffe8a8", "8894c0"]))
        if "peaks" in s:
            for i in range(3):
                base, x0 = 170 - i * 12, self.rng.randrange(40)
                for x in range(W):
                    u = (x + x0 * 13) % 170
                    top = base - abs(85 - u) * .8 + 60 + (x * 7 % 5)
                    self.img[int(max(top, 0)):, x] = rgb(s["peaks"])
        if s.get("rainbow"):
            for i, c in enumerate(["ec8ea3", "f4b880", "f4e090", "a8dca0", "98c8f0", "b8a8e8"]):
                band = ((xx - 320) ** 2 + (yy - 240) ** 2 < (250 - i * 4) ** 2) & ((xx - 320) ** 2 + (yy - 240) ** 2 >= (246 - i * 4) ** 2)
                self.img[band] = rgb(c)
        for _ in range(s.get("clouds", 0)):
            self.cloud(self.rng.randrange(W), self.rng.randrange(150), "ffffff", "e6f0f8")
        for _ in range(s.get("rays", 0)):
            x0, wid = self.rng.randrange(W), self.rng.randrange(8, 22)
            for y in range(H):
                x = int(x0 + y * .5)
                if (x + y) % 3:
                    self.img[y, max(x, 0) % W:min(x % W + wid, W)] = np.minimum(self.img[y, max(x, 0) % W:min(x % W + wid, W)] + 10, 255)
        if "seabed" in s:
            self.img[340:] = rgb(s["seabed"])

    def cloud(self, x, y, hi, lo):
        for _ in range(7):
            dx, dy, rad = self.rng.randrange(-26, 26), self.rng.randrange(-4, 5), self.rng.randrange(5, 11)
            yy, xx = np.ogrid[:H, :W]
            d = (xx - x - dx) ** 2 + (yy - y - dy) ** 2 < rad ** 2
            self.img[d & (yy > y + 2)] = rgb(lo)
            self.img[d & (yy <= y + 2)] = rgb(hi)

    # the rooms, as pixels: a cell's sides are wall only where its neighbour is another room
    def carve(self):
        for r in range(10):
            for c in range(16):
                ch, x0, y0 = self.rows[r][c], c * CW, r * CH
                if ch in " ^%":
                    self.room[y0:y0 + CH, x0:x0 + CW] = " "
                elif ch != "#":
                    lf = WALL if self.cell(c - 1, r) != ch else 0
                    t = WALL if self.cell(c, r - 1) != ch else 0
                    a = WALL if self.cell(c + 1, r) != ch else 0
                    b = FLOOR if self.cell(c, r + 1) != ch else 0
                    self.room[y0 + t:y0 + CH - b, x0 + lf:x0 + CW - a] = ch
        if self.w.get("cave"):
            self.wobble()

    def wobble(self):
        # cave walls gnawed a little, floors left flat for what stands on them
        keep = self.room.copy()
        for _ in range(3):
            air = self.room != "#"
            edge = air & ~(np.roll(air, 1, 0) & np.roll(air, -1, 0) & np.roll(air, 1, 1) & np.roll(air, -1, 1))
            bite = edge & (self.nr.random((H, W)) < .45) & (keep != " ")
            self.room[bite] = "#"
        air = self.room != "#"
        near = sum(np.roll(np.roll(air, dy, 0), dx, 1).astype(int) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        self.room[air & (near < 5)] = "#"
        fill = ~air & (near >= 6) & (keep != "#")
        self.room[fill] = keep[fill]
        for r in range(10):
            for c in range(16):
                ch = self.rows[r][c]
                if self.isroom(ch) and self.cell(c, r + 1) != ch:
                    y1, x0 = (r + 1) * CH - FLOOR, c * CW
                    span = keep[y1 - 22:y1, x0:x0 + CW]
                    self.room[y1 - 22:y1, x0:x0 + CW] = span
        self.room[keep == "Z"] = "Z"

    def links(self):
        # every neighbour is a candidate; first what joins the map, then a third of the rest
        cand = []
        for r in range(10):
            for c in range(16):
                a = self.cell(c, r)
                if not self.isroom(a):
                    continue
                b = self.cell(c + 1, r)
                if self.isroom(b) and b != a and self.cell(c, r + 1) != a and self.cell(c + 1, r + 1) != b:
                    cand.append(("door", c, r, a, b))
                b = self.cell(c, r + 1)
                if self.isroom(b) and b != a and "Z" not in (a, b):   # his room joins by doors: the rope stays clear
                    cand.append(("ladder", c, r, a, b))
        self.rng.shuffle(cand)
        parent = {}

        def find(x):
            parent.setdefault(x, x)
            while parent[x] != x:
                x = parent[x]
            return x
        self.door, self.ladder = [], []
        for kind, c, r, a, b in cand:
            join = find(a) != find(b)
            if join or self.rng.random() < .15:
                parent[find(a)] = find(b)
                (self.door if kind == "door" else self.ladder).append((c, r, a, b))
        for c, r, a, _ in self.door:
            x, y = (c + 1) * CW, (r + 1) * CH - FLOOR
            self.room[y - 20:y, x - WALL:x + WALL] = a
            self.busy[y - 20:y, x - WALL - 4:x + WALL + 4] = True
        for c, r, _, b in self.ladder:
            x, y = c * CW + 16, (r + 1) * CH
            self.room[y - FLOOR:y + WALL, x:x + 9] = b
            self.busy[y - FLOOR - 26:y + 30, x - 2:x + 11] = True

    # what the walls and floors are made of
    def solid(self):
        kind, lo, hi, top, line = self.w["rock"]
        lo, hi, top, line = map(rgb, (lo, hi, top, line))
        yy, xx = np.indices((H, W))
        if kind == "brick":
            joint = (yy % 8 == 0) | (((xx + 12 * ((yy // 8) % 2)) % 24) == 0)
            tex = np.where(joint[..., None], line, np.where(((xx // 3 + yy // 2) % 7 == 0)[..., None], hi, lo))
        elif kind == "strata":
            wave = (yy + (np.sin(xx / 17) * 3).astype(int) + (np.sin(xx / 5) * 1.5).astype(int))
            tex = np.where(((wave % 11) < 2)[..., None], hi, lo)
            tex = np.where(((wave % 11) == 2)[..., None], line, tex)
        elif kind == "earth":
            n = self.nr.random((H // 2, W // 2)).repeat(2, 0).repeat(2, 1) < .09
            tex = np.where(n[..., None], hi, lo)
            tex = np.where(((yy + (np.sin(xx / 23) * 4).astype(int)) % 19 == 0)[..., None], hi, tex)
        elif kind == "stone":
            joint = (yy % 12 == 0) | (((xx + 9 * ((yy // 12) % 2)) % 18) == 0)
            tex = np.where(joint[..., None], line, np.where(((xx + yy) % 11 == 0)[..., None], hi, lo))
        else:  # cloud, snow: soft dabs
            n = self.nr.random((H // 3 + 1, W // 3 + 1)).repeat(3, 0).repeat(3, 1)[:H, :W] < .2
            tex = np.where(n[..., None], hi, lo)
        rock = self.room == "#"
        self.img[rock] = tex[rock]
        # gems and bones in the rock: never a dead wall
        for _ in range(120):
            x, y = self.rng.randrange(1, W - 3), self.rng.randrange(1, H - 3)
            if rock[y - 1:y + 3, x - 1:x + 3].all():
                self.img[y:y + 2, x:x + 2] = rgb(self.rng.choice([self.ink["y"], self.ink["e"], self.ink["w"], self.ink["r"]]))
        air = ~rock
        up = np.roll(air, 1, 0)
        up[0] = False
        self.img[rock & up] = top
        second = np.roll(rock & up, 1, 0) & rock
        second[0] = False
        self.img[second] = (top.astype(int) * 3 // 4).astype(np.uint8)
        ink = rgb(self.ink["K"])
        side = rock & (np.roll(air, 1, 1) | np.roll(air, -1, 1) | np.roll(air, -1, 0))
        self.img[side & ~(rock & up)] = ink
        under = np.roll(second, 1, 0) & rock & ~second & ~(rock & up)
        self.img[under] = ink

    def backs(self):
        yy, xx = np.indices((H, W))
        letters = sorted(set("".join(self.rows)) - set(" #^%"))
        for ch in letters:
            pat, a, b = self.w["stage"] if ch == "Z" else self.rng.choice(self.w["backs"])
            a, b = rgb(a), rgb(b)
            m = self.room == ch
            if pat == "seigaiha":
                f = self.seigaiha()
            elif pat == "asanoha":
                f = self.asanoha()
            elif pat == "brick":
                f = (yy % 6 == 0) | ((xx + 6 * ((yy // 6) % 2)) % 12 == 0)
            elif pat == "plank":
                f = (xx % 7 == 0) | ((xx * 5 + yy // 9) % 41 == 0)
            elif pat == "shoji":
                f = (xx % 9 == 0) | (yy % 9 == 0)
            elif pat == "stone":
                f = (yy % 10 == 0) | ((xx + 8 * ((yy // 10) % 2)) % 16 == 0)
            elif pat == "cave":
                f = self.nr.random((H // 2, W // 2)).repeat(2, 0).repeat(2, 1) < .12
            else:
                t = np.clip((yy - yy[m].min()) / max(np.ptp(yy[m]), 1), 0, 1)
                f = t > BAYER[yy % 4, xx % 4]
            self.img[m] = np.where(f[..., None], b, a)[m]
            sh = m & ~np.roll(m, 1, 0)
            self.img[sh] = (self.img[sh].astype(int) * 3 // 4).astype(np.uint8)

    def seigaiha(self):
        # the wave of scales, drawn row over row
        f = np.zeros((H, W), bool)
        yy, xx = np.ogrid[:H, :W]
        for j in range(-1, H // 6 + 3):
            for i in range(-1, W // 24 + 2):
                cx, cy = i * 24 + (j % 2) * 12, j * 6
                d = (xx - cx) ** 2 + (yy - cy) ** 2
                f[d < 144] = False
                for rad in (12, 8, 4):
                    f |= (d < rad ** 2) & (d >= (rad - 1) ** 2)
        return f

    def asanoha(self):
        # the hemp leaf: a triangle's corners joined to its heart
        im = Image.new("1", (W, H))
        pen = ImageDraw.Draw(im)
        for j in range(-1, H // 14 + 2):
            for i in range(-1, W // 24 + 2):
                a, b, c = (i * 24 + (j % 2) * 12, j * 14), (i * 24 + 24 + (j % 2) * 12, j * 14), (i * 24 + 12 + (j % 2) * 12, j * 14 + 14)
                d = (i * 24 + 36 + (j % 2) * 12, j * 14 + 14)
                for tri in ((a, b, c), (b, c, d)):
                    mid = (sum(p[0] for p in tri) // 3, sum(p[1] for p in tri) // 3)
                    pen.polygon(tri, outline=1)
                    for p in tri:
                        pen.line((p, mid), fill=1)
        return np.array(im)

    def roofs(self):
        tile, mid, hi = map(rgb, self.w["roof"])
        ink = rgb(self.ink["K"])
        for r in range(10):
            c = 0
            while c < 16:
                if self.rows[r][c] != "^":
                    c += 1
                    continue
                e = c
                while e < 16 and self.rows[r][e] == "^":
                    e += 1
                x0, x1, top, h = c * CW, e * CW, r * CH, CH
                cx, half = (x0 + x1) / 2, (x1 - x0) / 2 + 7
                for i in range(h):
                    t = i / (h - 1)
                    hw = half * (.3 + .7 * t ** 2.2)
                    a, b = int(cx - hw), int(cx + hw)
                    a, b = max(a, 0), min(b, W)
                    row = np.where(((np.arange(a, b) - int(cx)) % 6 < 2)[:, None], mid, tile)
                    if i % 6 == 0:
                        row[:] = mid
                    self.img[top + i, a:b] = row
                    self.img[top + i, a] = self.img[top + i, max(b - 1, 0)] = ink
                self.img[top, int(cx - half * .3):int(cx + half * .3)] = hi
                self.img[top + 1, int(cx - half * .3):int(cx + half * .3)] = ink
                self.img[top + h - 2:top + h, max(int(cx - half), 0):min(int(cx + half), W)] = ink
                self.img[top + h - 3, max(int(cx - half), 0):min(int(cx + half), W)] = hi
                self.room[top:top + h, x0:x1] = "^"
                for dx in (-3, 2):   # the brass fish on the ridge
                    self.img[top - 3:top, int(cx) + dx:int(cx) + dx + 2] = rgb(self.ink["y"])
                c = e

    def canopy(self):
        # one mass, lit from the top left: never a pile of balls
        lo, mid, hi = map(rgb, self.w.get("canopy", ("4d8a3c", "86c057", "b4dc78")))
        yy, xx = np.ogrid[:H, :W]
        mass = np.zeros((H, W), bool)
        for r in range(10):
            for c in range(16):
                if self.rows[r][c] != "%":
                    continue
                for _ in range(14):
                    x, y = c * CW + self.rng.randrange(40), r * CH + self.rng.randrange(36)
                    mass |= (xx - x) ** 2 + (yy - y) ** 2 < self.rng.randrange(5, 12) ** 2
        mass = binary(binary(mass, 3, True), 3, False)   # no holes in it
        seen = Image.fromarray(np.uint8(mass) * 255, "L").copy()
        for x in np.flatnonzero(~mass[0]):
            if seen.getpixel((int(x), 0)) == 0:
                ImageDraw.floodfill(seen, (int(x), 0), 128)
        mass |= (np.array(seen) == 0) & (self.room == " ")
        mass &= self.room != "Z"
        ink = (lo.astype(int) * 7 // 10).astype(np.uint8)
        inner = mass & np.roll(mass, 1, 0) & np.roll(mass, -1, 0) & np.roll(mass, 1, 1) & np.roll(mass, -1, 1)
        self.img[mass] = ink
        self.img[inner] = lo
        down = np.roll(np.roll(inner, 3, 0), 2, 1) & inner
        self.img[down] = mid
        dabs = self.nr.random((H // 3 + 1, W // 3 + 1)).repeat(3, 0).repeat(3, 1)[:H, :W] < .28
        self.img[np.roll(np.roll(down, 3, 0), 2, 1) & down & dabs] = hi

    def blit(self, name, x, y, mark=True):
        s = self.sprites[name]
        for j, row in enumerate(s):
            for i, ch in enumerate(row):
                if ch != "." and 0 <= y + j < H and 0 <= x + i < W:
                    self.img[y + j, x + i] = rgb(self.ink[ch])
        if mark:
            self.busy[y:y + len(s), x:x + len(s[0])] = True
        if name in ("torch", "lantern", "hanglamp", "shrine", "cauldron", "crystal", "wisp"):
            self.lights.append((x + len(s[0]) // 2, y + len(s) // 2, 22 if name != "wisp" else 12))

    def free(self, name, x, y, ch):
        s = self.sprites[name]
        h, w = len(s), len(s[0])
        if y < 0 or x < 0 or y + h > H or x + w > W:
            return False
        area = self.room[y:y + h, x:x + w]
        return bool((area == ch).all()) and not self.busy[y:y + h, x:x + w].any()

    def shelf(self, x0, x1, y):
        self.img[y, x0:x1] = rgb(self.ink["a"])
        self.img[y + 1, x0:x1] = rgb(self.ink["c"])
        self.img[y + 2, x0:x1] = rgb(self.ink["K"])
        for x in (x0 + 2, x1 - 4):
            self.img[y + 3:y + 6, x:x + 2] = rgb(self.ink["K"])
        self.busy[y:y + 6, x0:x1] = True

    def furnish(self):
        # the floors first, shoulder to shoulder; then the ceilings; then the walls
        pos = [(c, r, self.rows[r][c]) for r in range(10) for c in range(16) if self.isroom(self.rows[r][c]) and self.rows[r][c] != "Z"]
        last = None
        for c, r, ch in pos:
            shelf = self.cell(c, r + 1) == ch and self.rng.random() < .8
            if self.cell(c, r + 1) != ch or shelf:
                x, end, y = c * CW + 1, (c + 1) * CW - 1, (r + 1) * CH - FLOOR
                if shelf:
                    y = (r + 1) * CH - 2
                    a, b = c * CW + self.rng.randrange(0, 6), (c + 1) * CW - self.rng.randrange(0, 6)
                    if self.busy[y:y + 3, a:b].any() or not (self.room[y:y + 3, a:b] == ch).all():
                        continue
                    self.shelf(a, b, y)
                    x, end = a + 1, b - 1
                while x < end:
                    name = self.rng.choice(self.w["floor"])
                    if name == last:
                        name = self.rng.choice(self.w["floor"])
                    h, wd = len(self.sprites[name]), len(self.sprites[name][0])
                    if self.free(name, x, y - h, ch):
                        self.blit(name, x, y - h)
                        last = name
                        x += wd + self.rng.randrange(1, 7)
                    else:
                        x += 3
        for c, r, ch in pos:
            if self.cell(c, r - 1) != ch:
                x, end = c * CW + self.rng.randrange(1, 12), (c + 1) * CW
                y = r * CH + WALL
                while x < end:
                    name = self.rng.choice(self.w["ceil"])
                    if self.free(name, x, y, ch):
                        self.blit(name, x, y)
                    x += self.rng.randrange(10, 24)
        for c, r, ch in pos:
            for _ in range(2):
                name = self.rng.choice(self.w["wall"])
                x, y = c * CW + self.rng.randrange(1, 28), r * CH + self.rng.randrange(1, 26)
                if self.free(name, x, y, ch):
                    self.blit(name, x, y)
        # the samurai's room stays clear: a light at each end, nothing near him
        self.dress_stage()
        y, a, b = STAGE_FLOOR, 5 * CW + WALL + 16, 11 * CW - WALL - 26
        for x in (a, b):
            self.blit("lantern", x, y - 11)
            self.blit("torch", x + 2, 7 * CH - 4)
        if self.w.get("banner"):
            for x in (a + 22, b - 22):
                self.blit("banner", x, 6 * CH + WALL + 1)

    def dress_stage(self):
        # two posts, a lintel and the sacred rope: a room built for the one who stands in it
        x0, x1, top, bot = 5 * CW + WALL, 11 * CW - WALL, 6 * CH + WALL, STAGE_FLOOR
        for x in (x0 + 2, x1 - 10):
            self.img[top:bot, x:x + 8] = rgb(self.ink["b"])
            self.img[top:bot, x + 1:x + 3] = rgb(self.ink["a"])
            self.img[top:bot, x + 6:x + 8] = rgb(self.ink["c"])
            self.img[top:bot, x - 1] = self.img[top:bot, x + 8] = rgb(self.ink["K"])
            self.img[bot - 5:bot, x - 2:x + 10] = rgb(self.ink["t"])
            self.img[bot - 6, x - 2:x + 10] = rgb(self.ink["K"])
        self.img[top:top + 4, x0:x1] = rgb(self.ink["b"])
        self.img[top + 4, x0:x1] = rgb(self.ink["K"])
        ax, bx = x0 + 12, x1 - 12
        for x in range(ax, bx):
            t = (x - ax) / (bx - ax)
            sag = int(top + 6 + 12 * 4 * t * (1 - t))
            self.img[sag:sag + 3, x] = rgb(self.ink["w"] if (x + sag) % 4 < 2 else self.ink["y"])
            self.img[sag + 3, x] = rgb(self.ink["K"])
            if (x - ax) % 36 == 18:  # the paper hanging from it
                for k in range(3):
                    self.img[sag + 4 + k * 3:sag + 7 + k * 3, x + k % 2:x + k % 2 + 4] = rgb(self.ink["w"])
                    self.img[sag + 4 + k * 3:sag + 7 + k * 3, x + k % 2 + 4] = rgb(self.ink["K"])
        self.busy[top:bot, x0:x1] = True

    def joints(self):
        for c, r, _, _ in self.door:
            x, y = (c + 1) * CW, (r + 1) * CH - FLOOR
            self.img[y - 21:y - 19, x - WALL - 1:x + WALL + 1] = rgb(self.ink["b"])
            self.img[y - 19, x - WALL - 1:x + WALL + 1] = rgb(self.ink["K"])
            self.img[y - 20:y, x - WALL - 2] = self.img[y - 20:y, x + WALL + 1] = rgb(self.ink["c"])
        for c, r, _, b in self.ladder:
            x, top, bot = c * CW + 16, (r + 1) * CH - FLOOR - 14, (r + 2) * CH - FLOOR
            if self.cell(c, r + 2) == b:
                bot += CH
            bot = min(bot, H)
            for side in (x, x + 8):
                self.img[top:bot, side] = rgb(self.ink["c"])
            for y in range(top + 2, bot, 4):
                self.img[y, x:x + 9] = rgb(self.ink["b"])

    def pools(self):
        pool = self.w.get("pool")
        if not pool:
            return
        _, deep, shine, p = pool
        letters = sorted(set("".join(self.rows)) - set(" #^%Z"))
        last = self.rows[9]
        for ch in letters:
            if self.rng.random() > p and not (self.w.get("lastpool") and ch in last):
                continue
            ys = np.where((self.room == ch).any(1))[0]
            depth = 12 if self.w.get("lastpool") and ch in last else 7
            y = ys.max() - depth
            m = (self.room == ch)
            m[:y] = False
            self.img[m] = rgb(deep)
            self.busy[m] = True
            yy, xx = np.indices((H, W))
            self.img[m & (yy == y)] = rgb(shine)
            self.img[m & (yy == y + 1) & (xx % 5 < 3)] = rgb(shine)
            self.img[m & (yy > y + 2) & ((xx * 3 + yy * 7) % 19 == 0)] = rgb(shine)

    def falls(self):
        for _ in range(self.w.get("falls", 0)):
            x = self.rng.choice([4, 6, 11, 12]) * CW + self.rng.randrange(20)
            for y in range(2 * CH, H):
                if self.room[y, x] not in " #Z" and self.room[y, x + 9] not in " #Z":
                    wid = 10
                    tone = np.where(((np.arange(wid) + y // 3) % 3 == 0)[:, None], rgb("f0fcff"), rgb("8cd8e8"))
                    self.img[y, x:x + wid] = tone

    def bits(self):
        name, n = self.w["bits"]
        for _ in range(n):
            x, y = self.rng.randrange(8, W - 24), self.rng.randrange(8, 200)
            if (self.room[y:y + 12, x:x + 12] == " ").all():
                self.blit(name, x, y)

    def glow(self):
        # torches light what is near them, in a dither, the dark worlds most
        yy, xx = np.indices((H, W))
        boost = np.zeros((H, W), int)
        for x, y, rad in self.lights:
            d = np.hypot(xx - x, yy - y) / rad
            boost += ((1 - d) > BAYER[yy % 4, xx % 4] * 1.2).astype(int)
        lit = (boost > 0) & (self.room != "#") & (self.room != " ")
        tone = np.array([26, 16, 4]) if self.mood == "dark" else np.array([8, 6, 0])
        self.img[lit] = np.minimum(self.img[lit].astype(int) + tone, 255).astype(np.uint8)

    def dust(self):
        kind = self.w.get("dust")
        tones = dict(petal=["f8bccb", "e88aa0"], ember=["ffa040", "ffd860"], snow=["ffffff"], spark=["ffffff", "fff4c4"],
                     bubble=["8ce0f0"], steam=["ffffff"])
        if not kind:
            return
        count = dict(petal=90, ember=120, snow=220, spark=60, bubble=70, steam=80)[kind]
        for _ in range(count):
            x, y = self.rng.randrange(1, W - 4), self.rng.randrange(1, H - 4)
            if self.room[y, x] == "Z":
                continue
            c = rgb(self.rng.choice(tones[kind]))
            if kind == "petal":
                self.img[y, x:x + 2] = c
                self.img[y + 1, x + 1:x + 3] = c
            elif kind == "bubble":
                self.img[y, x + 1] = self.img[y + 2, x + 1] = self.img[y + 1, x] = self.img[y + 1, x + 2] = c
            elif kind == "steam":
                self.img[y:y + 3, x + (y // 2) % 2] = c
            else:
                self.img[y, x] = c

    def minimap(self):
        # the corner's map is true: these rooms, this world; his room marked
        cw, ch, pad = 4, 3, 3
        mw, mh = 16 * cw + 2 * pad, 10 * ch + 2 * pad
        x0, y0 = W - mw - 6, 6
        ink = rgb(self.ink["K"])
        paper = rgb("10121c") if self.mood == "dark" else rgb("fff9ec")
        room = rgb("7c8aa0") if self.mood == "dark" else rgb("b8a890")
        self.img[y0 - 2:y0 + mh + 2, x0 - 2:x0 + mw + 2] = ink
        self.img[y0 - 1:y0 + mh + 1, x0 - 1:x0 + mw + 1] = rgb(self.ink["y"])
        self.img[y0:y0 + mh, x0:x0 + mw] = paper
        for dx, dy in ((-2, -2), (mw - 1, -2), (-2, mh - 1), (mw - 1, mh - 1)):
            self.img[y0 + dy:y0 + dy + 3, x0 + dx:x0 + dx + 3] = rgb(self.ink["Y"])
        for r in range(10):
            for c in range(16):
                a = self.rows[r][c]
                if not self.isroom(a):
                    continue
                x, y = x0 + pad + c * cw, y0 + pad + r * ch
                wd = cw if self.cell(c + 1, r) == a else cw - 1
                hg = ch if self.cell(c, r + 1) == a else ch - 1
                self.img[y:y + hg, x:x + wd] = rgb(self.ink["R"]) if a == "Z" else room
        for c, r, _, _ in self.door:
            self.img[y0 + pad + r * ch + 1, x0 + pad + c * cw + cw - 1] = room
        for c, r, _, _ in self.ladder:
            self.img[y0 + pad + r * ch + ch - 1, x0 + pad + c * cw + 1] = room
        self.busy[y0 - 2:y0 + mh + 2, x0 - 2:x0 + mw + 2] = True

    def build(self, mood):
        self.mood = mood
        self.sky()
        self.carve()
        self.links()
        self.solid()
        self.backs()
        self.roofs()
        self.canopy()
        self.pools()
        self.furnish()
        self.falls()
        self.joints()
        self.bits()
        self.glow()
        self.dust()
        self.minimap()
        return Image.fromarray(self.img, "RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    args = ap.parse_args()
    for mood, worlds in WORLDS.items():
        made = []
        for name, world in worlds.items():
            img = Map(world, name).build(mood)
            img.save(OUT / mood / f"lock-map-{name}.png", optimize=True)
            made.append(img)
        if args.preview:
            sheet = Image.new("RGB", (W * 2 + 4, H * 2 + 4), "#808080")
            for i, img in enumerate(made):
                sheet.paste(img, ((i % 2) * (W + 4), (i // 2) * (H + 4)))
            sheet.save(pathlib.Path(args.preview) / f"lockmap-{mood}.png")


if __name__ == "__main__":
    main()
