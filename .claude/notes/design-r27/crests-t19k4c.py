#!/usr/bin/env python3
"""T19k-4 (c): quick settings' crests — one 28 × 28 picture per switch, kamon style (one ink:
bold masses, 2 px strokes, 45° diagonals drawn as 3 px runs on the stair, details knocked out
1 px wide), the ink kept inside a circle 26 across (every inked pixel's centre within 13 of the
middle: 2 px of vermilion before the seal's paper ring at 15–16).

    python3 crests-t19k4c.py OUTDIR              → OUTDIR/crests-zoom.png, crests-1x.png
    python3 crests-t19k4c.py OUTDIR --export F   → also writes the drawings as art/crests.txt blocks

Coordinates are continuous: pixel (i, j) covers [i, i+1) × [j, j+1), its centre (i+.5, j+.5);
the picture's middle is (14, 14), the corner between pixels 13 and 14 (the seal's centre)."""
import math
import sys
from PIL import Image

N = 28
M = 14.0
LIMIT = 13.0


class Pic:
    def __init__(self):
        self.g = [[False] * N for _ in range(N)]

    def put(self, f, v=True):
        for j in range(N):
            for i in range(N):
                if f(i + .5, j + .5):
                    self.g[j][i] = v
        return self

    def disc(self, cx, cy, r, v=True):
        return self.put(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r, v)

    def ring(self, cx, cy, r_in, r_out, v=True):
        return self.put(lambda x, y: r_in * r_in < (x - cx) ** 2 + (y - cy) ** 2 <= r_out * r_out, v)

    def ellipse(self, cx, cy, rx, ry, v=True):
        return self.put(lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1, v)

    def rect(self, x0, y0, x1, y1, v=True):
        """pixels x0…x1, y0…y1 (inclusive, pixel indices)"""
        for j in range(max(0, y0), min(N, y1 + 1)):
            for i in range(max(0, x0), min(N, x1 + 1)):
                self.g[j][i] = v
        return self

    def px(self, pts, v=True):
        for i, j in pts:
            if 0 <= i < N and 0 <= j < N:
                self.g[j][i] = v
        return self

    def poly(self, pts, v=True):
        def inside(x, y):
            c = False
            n = len(pts)
            for k in range(n):
                (x1, y1), (x2, y2) = pts[k], pts[(k + 1) % n]
                if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
                    c = not c
            return c
        return self.put(inside, v)

    def seg(self, x0, y0, x1, y1, w, v=True):
        """a stroke w wide between two points (a capsule, by pixel centres)"""
        def d(x, y):
            dx, dy = x1 - x0, y1 - y0
            t = max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / (dx * dx + dy * dy)))
            return math.hypot(x - (x0 + t * dx), y - (y0 + t * dy))
        return self.put(lambda x, y: d(x, y) <= w / 2, v)

    def sector(self, cx, cy, r_in, r_out, a0, a1, v=True):
        """an annulus between two angles (degrees, 0 = right, 90 = up — the screen's y flipped)"""
        def f(x, y):
            r2 = (x - cx) ** 2 + (y - cy) ** 2
            if not r_in * r_in < r2 <= r_out * r_out:
                return False
            a = math.degrees(math.atan2(cy - y, x - cx)) % 360
            return (a - a0) % 360 <= (a1 - a0) % 360
        return self.put(f, v)

    def mirror(self):
        """the left half copied onto the right (symmetric about x = 14)"""
        for j in range(N):
            for i in range(N // 2):
                self.g[j][N - 1 - i] = self.g[j][i]
        return self

    def art(self, text, x0=0, y0=0):
        """hand-drawn rows: '#' ink, 'o' knocked out, anything else left as it is"""
        for j, row in enumerate(text.strip("\n").splitlines()):
            for i, c in enumerate(row):
                if c == "#":
                    self.g[y0 + j][x0 + i] = True
                elif c == "o":
                    self.g[y0 + j][x0 + i] = False
        return self

    def shift(self, dx, dy):
        g = [[False] * N for _ in range(N)]
        for j in range(N):
            for i in range(N):
                if self.g[j][i] and 0 <= i + dx < N and 0 <= j + dy < N:
                    g[j + dy][i + dx] = True
        self.g = g
        return self

    def clean(self, least=3):
        """crumbs (8-connected pieces of fewer than `least` pixels) removed"""
        seen = set()
        for j in range(N):
            for i in range(N):
                if self.g[j][i] and (i, j) not in seen:
                    comp, todo = [], [(i, j)]
                    seen.add((i, j))
                    while todo:
                        a, b = todo.pop()
                        comp.append((a, b))
                        for da in (-1, 0, 1):
                            for db in (-1, 0, 1):
                                q = (a + da, b + db)
                                if 0 <= q[0] < N and 0 <= q[1] < N and self.g[q[1]][q[0]] and q not in seen:
                                    seen.add(q)
                                    todo.append(q)
                    if len(comp) < least:
                        for a, b in comp:
                            self.g[b][a] = False
        return self

    def crumbs(self, least=3):
        before = sum(map(sum, self.g))
        q = Pic()
        q.g = [r[:] for r in self.g]
        return before - sum(map(sum, q.clean(least).g))

    def rows(self):
        return ["".join("#" if v else "." for v in r) for r in self.g]

    def beyond(self):
        """inked pixels whose centre is outside the circle of LIMIT"""
        return [(i, j) for j in range(N) for i in range(N)
                if self.g[j][i] and math.hypot(i + .5 - M, j + .5 - M) > LIMIT + 1e-9]

    def bbox(self):
        ink = [(i, j) for j in range(N) for i in range(N) if self.g[j][i]]
        xs, ys = [i for i, _ in ink], [j for _, j in ink]
        return min(xs), min(ys), max(xs), max(ys)


def hires(draw, thr=0.5, S=8):
    """draw(d, S) on a canvas S× the grid (PIL ImageDraw, ink 255), each pixel of the picture
    inked when more than thr of its S × S block is — organic curves, then cleaned by hand"""
    from PIL import ImageDraw
    big = Image.new("L", (N * S, N * S), 0)
    draw(ImageDraw.Draw(big), S)
    p = Pic()
    px = big.load()
    for j in range(N):
        for i in range(N):
            tot = sum(px[i * S + a, j * S + b] for a in range(S) for b in range(S))
            p.g[j][i] = tot / (255 * S * S) > thr
    return p


def bez(pts, n=64):
    """a cubic Bézier's points (4 control points, in grid units)"""
    (x0, y0), (x1, y1), (x2, y2), (x3, y3) = pts
    out = []
    for k in range(n + 1):
        t = k / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * x0 + b * x1 + c * x2 + d * x3, a * y0 + b * y1 + c * y2 + d * y3))
    return out


def stroke(d, S, pts, w):
    """a polyline w grid units wide, round-jointed"""
    P = [(x * S, y * S) for x, y in pts]
    d.line(P, fill=255, width=int(round(w * S)), joint="curve")
    r = w * S / 2
    for x, y in (P[0], P[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)


# ── the drawings ──────────────────────────────────────────────────────────────────────────────

def moon():
    # a crescent (三日月): a disc less a disc set up and right — its horns point right
    p = Pic().disc(M, M, 12.2)
    p.disc(M + 5.4, M - 3.6, 10.0, False)
    return p


def moon_star():
    # 月に星 (the moon and a star, the Chiba crest): the crescent and a small disc in its arms
    p = moon()
    p.disc(19.6, 13.4, 2.6)
    return p


def sun():
    # the light mood: a disc and eight wedge rays (polar wedges by pixel centres: 3.4 px at the
    # root, 1 at the tip), the diagonals a step shorter so they read as long as the straight ones
    p = Pic().disc(M, M, 6.0)
    def ray(x, y):
        r = math.hypot(x - M, y - M)
        a = math.atan2(y - M, x - M)
        for k in range(8):
            r0, r1 = 8.0, (13.0 if k % 2 == 0 else 12.2)
            if not r0 <= r <= r1:
                continue
            w = 3.6 + (1.2 - 3.6) * (r - r0) / (r1 - r0)
            d = abs((a - k * math.pi / 4 + math.pi) % (2 * math.pi) - math.pi)
            if d < math.pi / 2 and r * math.sin(d) <= w / 2:
                return True
        return False
    return p.put(ray)


def lantern():
    # the night light: a chōchin (提灯) — a handle's arch, a lid and a foot of black lacquer
    # (10 wide, 3 rows), the round paper body between (an oval 18 × 16) whose bamboo ribs show
    # as three knocked-out lines bowing with the paper (∩ above the middle, ∪ below)
    p = Pic()
    p.art("""
....####....
....#..#....
..########..
.##########.
.##########.
""", 8, 1)
    p.ellipse(M, 14.5, 9.2, 8.6)
    # ribs: knocked out, bowing with the paper
    for x in range(N):
        cx = x + .5 - M
        bow = round(cx * cx / 40.0)             # 0 in the middle, 1–2 at the edges
        for y0, sgn in ((10, -1), (14, 0), (18, 1)):
            y = y0 + sgn * bow
            if 0 <= y < N:
                p.g[y][x] = False
    p.art("""
.##########.
.##########.
..########..
""", 8, 23)
    return p


def wave():
    # freesync: a wave rising from the right and breaking to the left (after Hokusai's), its
    # lip curled into the hollow, three claws of foam on its edge, the swell's line under it
    p = Pic()
    p.art("""
............................
............................
.............######.........
..........##########........
.........####....#####......
........###........####.....
.......###..........####....
......###..####......####...
.....###..######......###...
.....##..###..###......###..
....###..##....##......###..
....##..###..#.##.......##..
....##..##..##.##.......###.
....##..##..####........###.
.###....###............####.
..###....####.........#####.
...###.....######...######..
....#####....############...
.#....######...########.....
.##.....#######.............
..###.........########......
...######.........######....
.....###########.......###..
..........##############....
................######......
............................
............................
............................
""")
    return p


def ethernet():
    # the network by cable: an RJ45 socket seen from the front — its shell, the opening, the
    # eight contacts hanging from the top, the latch's slot at the foot
    p = Pic().rect(4, 5, 23, 22)
    p.px([(4, 5), (23, 5), (4, 22), (23, 22)], False)
    p.rect(6, 7, 21, 18, False)            # the opening
    p.rect(10, 19, 17, 20, False)          # the latch's slot
    for k in range(8):                      # the contacts: 1 px, a gap of 1, from the top
        x = 6 + 2 * k + (1 if k >= 4 else 0)
        p.rect(x, 7, x, 10)
    return p


def wifi():
    # wireless: three arcs and the dot, a quarter of a circle wide
    cx, cy = M, 20.5
    p = Pic().disc(cx, cy, 2.1)
    for r0, r1 in ((5.0, 7.2), (9.0, 11.2), (13.0, 15.2)):
        p.sector(cx, cy, r0, r1, 45, 135)
    return p


def offline():
    # no network: the arcs cut by a slash, a gap either side of it
    p = wifi()
    p.seg(5.5, 5.5, 22.5, 22.5, 4.6, False)
    p.seg(6.5, 6.5, 22.0, 22.0, 2.2)
    return p


def bluetooth():
    # the rune (ᚼ ᛒ): the stem and the two bows, 2 px strokes, the diagonals on the stair
    p = Pic().rect(13, 2, 14, 25)
    p.seg(14.0, 3.0, 20.0, 9.0, 2.3)
    p.seg(20.0, 9.0, 8.0, 20.0, 2.3)
    p.seg(14.0, 25.0, 20.0, 19.0, 2.3)
    p.seg(20.0, 19.0, 8.0, 8.0, 2.3)
    return p


def devices():
    # devices (bluetooth's): headphones — the band an arc 2 px thick, the cups each a shell
    # and its cushion, a knocked-out line between
    p = Pic().sector(M, 15.0, 8.0, 10.2, 0, 180)
    p.rect(4, 15, 9, 23)
    p.rect(18, 15, 23, 23)
    p.px([(4, 15), (4, 23), (23, 15), (23, 23)], False)
    p.rect(7, 15, 7, 23, False)
    p.rect(20, 15, 20, 23, False)
    return p


def drive():
    # drives: a USB stick, the plug up — its shell with the two windows, the body, a light
    p = Pic()
    p.rect(9, 2, 18, 9)
    p.rect(11, 4, 12, 5, False)
    p.rect(15, 4, 16, 5, False)
    p.rect(9, 8, 18, 8, False)              # where the shell meets the body
    p.rect(7, 10, 20, 25)
    p.px([(7, 25), (20, 25), (7, 24), (20, 24), (8, 25), (19, 25)], False)
    p.rect(13, 20, 14, 21, False)           # the light
    return p


def backup():
    # backup: a kura (蔵), the storehouse where a family kept what it could not lose — the
    # heavy roof with its ridge tiles, the white walls, the shuttered window, the namako
    # lattice on the walls' foot
    p = Pic()
    p.art("""
.....##..............##.....
.....################.......
....##################......
...####################.....
..######################....
.##########################.
.##..................... ##.
""".replace(" ", "."), 0, 2)
    p.rect(5, 10, 22, 24)
    p.rect(12, 12, 15, 14, False)           # the window
    for j in range(17, 25):                  # namako: a lattice of diagonals, every 4th
        for i in range(5, 23):
            if (i + j) % 4 == 0 or (i - j) % 4 == 0:
                p.g[j][i] = False
    return p


def bell():
    # dnd off (notices ring): a bonshō (梵鐘), the temple bell — its lug, the crown, the body
    # with the nodules' two panels, the band, the striking seat, the rim
    p = Pic()
    p.art("""
...####...
..##..##..
..##..##..
""", 9, 1)
    p.rect(8, 4, 19, 5)
    p.rect(7, 6, 20, 22)
    p.rect(6, 20, 21, 23)
    p.px([(6, 20), (21, 20)], False)
    p.rect(7, 7, 20, 7, False)               # under the crown
    for y in (9, 11, 13):                    # the nodules
        for x in (9, 11, 16, 18):
            p.g[y][x] = False
    p.rect(13, 8, 14, 14, False)             # between the panels
    p.rect(7, 15, 20, 15, False)             # the band
    p.ring(14.0, 18.5, 1.0, 2.2, False)      # the striking seat
    p.rect(6, 21, 21, 21, False)             # the rim
    return p


def bell_off():
    # dnd on: the bell, silenced — a slash across it, a gap either side
    p = bell()
    p.seg(4.0, 4.0, 24.0, 24.0, 4.6, False)
    p.seg(5.0, 5.0, 23.5, 23.5, 2.2)
    return p


def saver():
    # the screensaver is sashiko: a needle (its eye up), the thread from the eye running down
    # into a line of stitches across the cloth
    p = Pic()
    p.seg(22.0, 4.0, 8.0, 18.0, 2.3)
    p.seg(23.5, 2.5, 20.0, 6.0, 3.2)
    p.seg(22.6, 3.4, 21.4, 4.6, 1.0, False)   # the eye
    p.art("""
.....#####...####...####....
....#..............  .......
""".replace(" ", "."), 0, 22)
    return p


def record():
    # record: a cine camera — two reels on top, the body, the lens to the right
    p = Pic()
    for cx in (9.0, 18.5):
        p.disc(cx, 7.5, 4.6)
        p.disc(cx, 7.5, 1.2, False)
    p.rect(5, 13, 20, 22)
    p.px([(5, 13), (20, 13), (5, 22), (20, 22)], False)
    p.poly([(21.0, 16.0), (25.0, 14.0), (25.0, 21.0), (21.0, 19.0)])
    return p


def read():
    # read text: a region's corners, three lines of words in it
    p = Pic()
    for (x, y, dx, dy) in ((5, 5, 1, 1), (22, 5, -1, 1), (5, 22, 1, -1), (22, 22, -1, -1)):
        p.rect(min(x, x + dx * 5), min(y, y + dy), max(x, x + dx * 5), max(y, y + dy))
        p.rect(min(x, x + dx), min(y, y + dy * 5), max(x, x + dx), max(y, y + dy * 5))
    p.rect(9, 9, 13, 10); p.rect(15, 9, 18, 10)
    p.rect(9, 13, 18, 14)
    p.rect(9, 17, 11, 18); p.rect(13, 17, 16, 18)
    return p


def sun_bars():
    # the sun, rays as bars: straight ones 2 px, the diagonals 3 px runs on the stair
    p = Pic().disc(M, M, 6.2)
    for k in range(8):
        a = k * math.pi / 4
        ux, uy = math.cos(a), math.sin(a)
        r1 = 12.6 if k % 2 == 0 else 11.8
        p.seg(M + ux * 8.6, M + uy * 8.6, M + ux * r1, M + uy * r1, 2.0 if k % 2 == 0 else 2.3)
    return p


def sun_ring():
    # the sun, kamon "hi": a disc, a gap, a ring of sixteen short rays
    p = Pic().disc(M, M, 6.6)
    def f(x, y):
        r = math.hypot(x - M, y - M)
        if not 9.0 <= r <= 12.8:
            return False
        a = math.degrees(math.atan2(y - M, x - M)) % 22.5
        return min(a, 22.5 - a) * math.pi / 180 * r <= 1.15
    return p.put(f)


def lantern2():
    # the chōchin again: taller than wide, the ribs stopping short of the paper's edge (the
    # oval whole), the lid and foot black, the handle an arch
    p = Pic()
    p.art("""
...######...
..##....##..
.##########.
############
############
""", 8, 1)
    p.ellipse(M, 14.0, 8.6, 9.0)
    for y in (8, 11, 14, 17, 20):
        row = [i for i in range(N) if p.g[y][i]]
        for i in row[2:-2]:
            p.g[y][i] = False
    p.art("""
############
############
.##########.
""", 8, 22)
    return p


def lantern3():
    # the chōchin with its family crest: two ribs near lid and foot, a ring in the middle
    p = lantern2()
    for y in (11, 17):
        for i in range(N):
            if 4 < i < 23 and not p.g[y][i]:
                p.g[y][i] = True
    p.ring(M, 14.0, 2.4, 4.0, False)
    return p


def wave2():
    # freesync: a wave breaking to the left — the swell rising from the sea on the right, its
    # crest curling over the hollow, three claws of foam at its lip
    def draw(d, S):
        # the body: an annulus band from the sea on the right, over the top, down the left
        cx, cy = 14.5 * S, 13.5 * S
        d.pieslice((cx - 11.5 * S, cy - 11.5 * S, cx + 11.5 * S, cy + 11.5 * S), 160, 420, fill=255)
        d.ellipse((cx - 6.6 * S, cy - 6.6 * S, cx + 6.6 * S, cy + 6.6 * S), fill=0)
        d.pieslice((cx - 11.5 * S, cy - 11.5 * S, cx + 11.5 * S, cy + 11.5 * S), 60, 160, fill=0)
        # the sea under it
        d.rectangle((3.0 * S, 20.0 * S, 25.0 * S, 24.0 * S), fill=255)
        # the lip curling into the hollow: a hook from the crest's left end
        stroke(d, S, bez([(4.4, 15.0), (5.5, 18.5), (9.5, 18.8), (10.2, 15.2)]), 2.4)
    p = hires(draw)
    return p


def bell2():
    # a bonshō: the lug, a domed crown, the body a little wider at the rim; knocked out: the
    # band under the shoulder, the middle band, the panels' divide, the striking seat
    def draw(d, S):
        d.ellipse((7.0 * S, 4.0 * S, 21.0 * S, 12.0 * S), fill=255)              # the crown
        d.polygon([(7.0 * S, 8.0 * S), (21.0 * S, 8.0 * S), (22.0 * S, 24.0 * S), (6.0 * S, 24.0 * S)], fill=255)
        stroke(d, S, bez([(11.5, 4.6), (11.5, 0.8), (16.5, 0.8), (16.5, 4.6)]), 2.2)  # the lug
    p = hires(draw)
    p.rect(7, 9, 20, 9, False)              # under the shoulder
    p.rect(13, 10, 14, 15, False)           # the panels' divide
    p.rect(6, 16, 21, 16, False)            # the middle band
    p.ring(14.0, 19.6, 0.9, 2.1, False)     # the striking seat
    p.rect(6, 22, 21, 22, False)            # the rim
    return p


def bell2_off():
    p = bell2()
    p.seg(4.0, 4.0, 24.0, 24.0, 4.4, False)
    p.seg(5.0, 5.0, 23.0, 23.0, 2.2)
    return p


def saver2():
    # sashiko: the needle (thin: 2 px runs on the stair, its point down-left), its eye a slot
    # in the head, the thread from the eye looping down into three stitches
    def draw(d, S):
        stroke(d, S, [(5.4, 22.6), (21.2, 6.8)], 1.6)                      # the shaft
        stroke(d, S, [(19.4, 8.6), (22.6, 5.4)], 3.0)                      # the head
        stroke(d, S, bez([(22.6, 5.4), (27.0, 9.0), (22.0, 17.5), (16.0, 19.0)]), 1.6)   # the thread
    p = hires(draw, 0.45)
    p.seg(20.2, 7.8, 22.0, 6.0, 0.9, False)                                 # the eye
    for x0 in (4, 9, 14):
        p.rect(x0 + 1, 24, x0 + 3, 25)                                      # the stitches
    return p


def chest():
    # backup: a senryō-bako (千両箱), the iron-bound chest a house kept its gold in — the lid,
    # the bands, the lock plate
    p = Pic().rect(4, 7, 23, 22)
    p.px([(4, 7), (23, 7), (4, 22), (23, 22)], False)
    p.rect(4, 11, 23, 11, False)            # the lid's edge
    p.rect(8, 7, 8, 22, False); p.rect(10, 7, 10, 22, False)      # the iron bands (knocked
    p.rect(17, 7, 17, 22, False); p.rect(19, 7, 19, 22, False)    #  out either side)
    p.rect(12, 12, 15, 16, False)           # the lock plate
    p.rect(13, 13, 14, 15)
    return p


def kura2():
    # backup: the kura, smaller and calmer — ridge with its two oni tiles, the roof, the
    # eaves' band, the walls, a door with its frame stepped in
    p = Pic()
    p.art("""
....##............##....
....################....
...##################...
..####################..
.######################.
########################
""", 2, 3)
    p.rect(5, 10, 22, 24)
    p.rect(5, 12, 22, 12, False)            # the band under the eaves
    p.rect(11, 15, 16, 24, False)           # the door
    p.rect(12, 16, 15, 24)
    p.rect(13, 17, 14, 24, False)
    return p


def lantern4():
    # a bura chōchin: the paper round (an oval a little wider than tall), three ribs stopping
    # short of its edge, the black lid and foot, a cord and tassel under it
    p = Pic()
    p.art("""
..########..
.##########.
.##########.
""", 8, 2)
    p.ellipse(M, 13.5, 10.2, 8.4)
    for y in (9, 13, 17):
        row = [i for i in range(N) if p.g[y][i]]
        for i in row[2:-2]:
            p.g[y][i] = False
    p.art("""
.##########.
.##########.
..########..
.....##.....
....####....
""", 8, 21)
    return p


def toro():
    # a tōrō (灯籠), the stone lantern of a temple garden: the jewel on top, the roof with its
    # turned-up corners, the fire box with its window (the light), the post, the base
    p = Pic()
    p.art("""
.............##.............
............####............
...........######...........
........############........
.....##################.....
...######################...
..##....................##..
.......##############.......
.......###...##...###.......
.......###...##...###.......
.......###...##...###.......
.......##############.......
.....##################.....
..........########..........
...........######...........
...........######...........
...........######...........
...........######...........
.........##########.........
.......##############.......
......################......
""".replace(" ", "."), 0, 3)
    return p


def wave3():
    # freesync: Hokusai's wave in small — the swell from the right, the crest curling over a
    # hollow, three claws of foam hanging from its lip, the sea's line under it
    def draw(d, S):
        c = lambda *pts: [(x * S, y * S) for x, y in pts]
        outer = bez([(24.5, 21.5), (27.0, 12.0), (22.0, 3.0), (13.0, 3.0)]) + \
                bez([(13.0, 3.0), (6.0, 3.0), (2.5, 9.0), (4.0, 14.5)])
        inner = bez([(9.0, 13.5), (8.0, 9.5), (11.0, 7.5), (14.0, 7.5)]) + \
                bez([(14.0, 7.5), (19.0, 7.5), (20.5, 13.0), (17.5, 21.5)])
        d.polygon(c(*outer, *reversed(inner)), fill=255)
        # the claws: three small hooks under the lip, pointing down and left
        for (x, y) in ((4.2, 14.0), (6.4, 14.6), (8.6, 14.2)):
            d.polygon(c((x - 1.3, y - 1.0), (x + 1.2, y - 1.0), (x - 0.6, y + 2.6)), fill=255)
        # the sea: a band under all, its top a low swell
        d.polygon(c(*bez([(3.0, 22.0), (8.0, 20.0), (12.0, 21.5), (17.0, 20.5)]),
                    (24.5, 20.5), (24.0, 23.5), (4.0, 23.5)), fill=255)
    p = hires(draw)
    return p


def bell3():
    # a bonshō, calmer: the lug a ring, the crown a dome, the body straight to a rim a little
    # wider; knocked out only the middle band and the striking seat
    def draw(d, S):
        d.ellipse((7.0 * S, 5.0 * S, 21.0 * S, 13.0 * S), fill=255)
        d.polygon([(7.0 * S, 9.0 * S), (21.0 * S, 9.0 * S), (21.6 * S, 24.0 * S), (6.4 * S, 24.0 * S)], fill=255)
        d.ellipse((10.6 * S, 0.8 * S, 17.4 * S, 7.6 * S), fill=255)
        d.ellipse((12.4 * S, 2.6 * S, 15.6 * S, 5.8 * S), fill=0)
    p = hires(draw)
    p.rect(6, 15, 21, 15, False)            # the middle band
    p.rect(6, 17, 21, 17, False)
    p.ring(14.0, 20.6, 0.9, 2.1, False)     # the striking seat
    return p


def suzu():
    # a suzu (鈴), the shrine's round bell: its loop, the band round its middle, the mouth (a
    # slit ending in two holes) under it
    p = Pic()
    p.disc(M, 15.0, 10.0)
    p.ring(M, 3.6, 1.4, 3.4)
    p.rect(13, 5, 14, 5)
    p.rect(4, 14, 23, 14, False)            # the band
    p.rect(4, 16, 23, 16, False)
    p.rect(9, 20, 18, 20, False)            # the mouth
    p.disc(8.6, 20.5, 1.3, False)
    p.disc(19.4, 20.5, 1.3, False)
    return p


def saver3():
    # sashiko: the needle at 45° (its point down-left), the eye a slot in its head, the thread
    # from the eye down the right in an S and along the foot as three stitches
    def draw(d, S):
        stroke(d, S, [(4.6, 23.4), (20.0, 8.0)], 1.5)
        stroke(d, S, [(18.6, 9.4), (22.4, 5.6)], 2.8)
        stroke(d, S, bez([(21.6, 6.4), (26.0, 10.0), (17.0, 15.0), (21.5, 20.5)]), 1.6)
    p = hires(draw, 0.45)
    p.seg(19.4, 8.6, 21.6, 6.4, 0.8, False)                 # the eye
    for x0 in (8, 13, 18):
        p.rect(x0, 23, x0 + 2, 24)                          # the stitches
    return p


def wave4():
    # freesync: the Great Wave in small — a thick band from the sea on the right over the top
    # to its lip on the left, three bold claws hanging from the lip, the hollow under the curl
    # open to the sea, the sea a band across the foot
    def draw(d, S):
        c = lambda pts: [(x * S, y * S) for x, y in pts]
        outer = bez([(24.0, 21.0), (27.5, 12.0), (22.5, 2.5), (13.5, 2.5)]) + \
                bez([(13.5, 2.5), (6.0, 2.5), (2.2, 8.0), (3.0, 13.0)])
        inner = bez([(8.4, 12.0), (8.6, 8.2), (11.5, 7.2), (14.0, 7.2)]) + \
                bez([(14.0, 7.2), (18.5, 7.2), (20.0, 12.0), (17.0, 20.5)])
        d.polygon(c(outer + [(3.0, 13.0), (8.4, 12.0)][::-1][:0] + list(reversed(inner))), fill=255)
        for x0 in (3.6, 6.4, 9.2):                       # the claws: hooks curling in
            stroke(d, S, bez([(x0, 11.5), (x0 - 0.6, 14.0), (x0 + 0.2, 16.0), (x0 + 1.6, 15.6)]), 1.9)
        d.polygon(c(bez([(4.0, 21.5), (9.0, 19.5), (13.0, 21.0), (17.5, 20.0)]) +
                    [(24.0, 20.5), (23.5, 23.6), (4.5, 23.6)]), fill=255)
    return hires(draw)


def toro2():
    # the stone lantern, refined: the jewel, the roof's corners turned up, the fire box's one
    # window wide open (the light), the platform, the post, the base
    p = Pic()
    p.art("""
.............##.............
............####............
.............##.............
.........##########.........
.......##############.......
....######################..
...##....................##.
""".replace(" ", "."), 0, 2)
    p.g[7][3] = p.g[7][24] = False
    p.art("""
.......##############.......
.......##..........##.......
.......##..........##.......
.......##..........##.......
.......##############.......
.....##################.....
...........######...........
...........######...........
...........######...........
.........##########.........
.......##############.......
......################......
""", 0, 10)
    return p


def bell4():
    # the bonshō with a proper ring for its lug
    p = bell3()
    p.rect(10, 0, 17, 8, False)
    p.art("""
.####.
##..##
##..##
.####.
""", 11, 1)
    p.rect(9, 5, 18, 5)
    return p


def bell4_off():
    p = bell4()
    p.seg(4.5, 4.5, 23.5, 23.5, 4.4, False)
    p.seg(5.5, 5.5, 22.5, 22.5, 2.2)
    return p


def saver4():
    # sashiko: three stitches running in from the left, the needle rising out of the cloth at
    # the end of the last, its eye up; the thread from the eye drooping back to the stitch
    def draw(d, S):
        stroke(d, S, [(14.6, 21.8), (22.4, 5.0)], 1.6)                 # the shaft
        stroke(d, S, [(21.3, 7.4), (22.8, 4.2)], 2.8)                  # the head
        stroke(d, S, bez([(22.4, 5.0), (26.0, 10.0), (23.0, 19.0), (16.5, 21.6)]), 1.7)
    p = hires(draw, 0.45)
    p.seg(21.6, 6.8, 22.4, 5.0, 0.8, False)
    for x0 in (2, 7, 12):
        p.rect(x0 + 1, 21, x0 + 3, 22)
    return p


def saver5():
    # sashiko: the needle upright (point down), its eye a slot, the thread looping out of the
    # eye to the right and down into three stitches along the foot
    p = Pic()
    p.art("""
.##.
#..#
#..#
#..#
#..#
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
..#.
""", 6, 3)
    def draw(d, S):
        stroke(d, S, bez([(9.5, 5.0), (16.0, 1.5), (22.0, 6.0), (17.0, 12.0)]) +
               bez([(17.0, 12.0), (12.0, 18.0), (16.0, 22.5), (21.0, 21.5)]), 1.9)
    q = hires(draw, 0.45)
    for j in range(N):
        for i in range(N):
            p.g[j][i] = p.g[j][i] or q.g[j][i]
    for x0 in (13, 18):
        pass
    p.rect(4, 22, 6, 23); p.rect(11, 22, 13, 23)
    return p


def wave6():
    # freesync: water — three bands of swell, the top one breaking into a curl at its right
    def draw(d, S):
        def band(y0, x0, x1, amp, ph, w):
            pts = [(x0 + (x1 - x0) * k / 60, y0 + amp * math.sin(ph + (x1 - x0) * k / 60 * 2 * math.pi / 9.0))
                   for k in range(61)]
            stroke(d, S, pts, w)
            return pts[-1]
        end = band(8.6, 3.8, 18.0, 1.3, 0.0, 2.2)
        # the curl: from the band's end up and round into itself
        stroke(d, S, bez([end, (21.5, 6.0), (24.8, 9.2), (22.4, 12.4)]) +
               bez([(22.4, 12.4), (20.6, 14.6), (17.6, 12.6), (19.6, 10.6)]), 2.2)
        band(16.0, 3.2, 24.8, 1.3, 2.2, 2.2)
        band(22.6, 6.0, 22.0, 1.1, 4.0, 2.2)
    return hires(draw)


def toro3():
    # the stone lantern: a jewel (a small spire), the roof heavy with its corners turned up,
    # the fire box with its two windows and the post between, the platform, the post, the base
    p = Pic()
    p.art("""
.............##.............
............####............
...........######...........
........############........
.....##################.....
...######################...
..###..................###..
""".replace(" ", "."), 0, 2)
    p.art("""
.......##############.......
.......##...####...##.......
.......##...####...##.......
.......##...####...##.......
.......##############.......
.....##################.....
...........######...........
...........######...........
...........######...........
.........##########.........
.......##############.......
......################......
""", 0, 10)
    return p


def bell5():
    # the bonshō by hand: a small lug, the crown a dome, the body widening a little to the
    # rim; knocked out the band under the shoulder, the middle bands, the striking seat
    p = Pic()
    p.art("""
............####............
...........##..##...........
.........##########.........
........############........
.......##############.......
.......##############.......
.......oooooooooooooo.......
.......##############.......
.......######oo######.......
.......######oo######.......
.......######oo######.......
.......######oo######.......
.......##############.......
......oooooooooooooooo......
......################......
......oooooooooooooooo......
......#######oo#######......
......######oooo######......
......#######oo#######......
......################......
.....##################.....
.....##################.....
""", 0, 2)
    return p


def bell5_off():
    p = bell5()
    p.seg(4.5, 4.5, 23.5, 23.5, 4.4, False)
    p.seg(5.5, 5.5, 22.5, 22.5, 2.2)
    return p


def spool():
    # the saver is sashiko: a spool of thread (its two flanges, the wound thread between) and
    # a needle through it, its eye up and to the right
    p = Pic()
    p.rect(7, 4, 20, 6)                      # the top flange
    p.rect(9, 7, 18, 20)                     # the thread
    for y in (9, 12, 15, 18):
        p.rect(9, y, 18, y, False)
    p.rect(7, 21, 20, 23)                    # the bottom flange
    p.px([(7, 4), (20, 4), (7, 23), (20, 23)], False)
    p.seg(5.0, 23.0, 23.0, 5.0, 4.4, False)  # the needle's gap
    p.seg(5.6, 22.4, 22.6, 5.4, 2.2)         # the needle
    p.seg(21.6, 6.4, 23.2, 4.8, 3.2)         # its head
    p.seg(22.0, 6.0, 22.8, 5.2, 0.9, False)  # its eye
    return p


def bell6():
    # dnd off (notices ring): a bonshō (梵鐘) — a small arched lug, the crown a dome, the body
    # straight to a rim a little wider; knocked out the two middle bands and the striking seat
    def draw(d, S):
        d.ellipse((7.0 * S, 4.0 * S, 21.0 * S, 16.0 * S), fill=255)
        d.polygon([(7.0 * S, 10.0 * S), (21.0 * S, 10.0 * S), (21.6 * S, 24.0 * S), (6.4 * S, 24.0 * S)], fill=255)
    p = hires(draw)
    p.art("""
.####.
##..##
""", 11, 2)
    p.rect(6, 15, 21, 15, False)
    p.rect(6, 17, 21, 17, False)
    p.ring(14.0, 20.6, 0.9, 2.1, False)
    return p


def bell6_off():
    p = bell6()
    p.seg(4.5, 4.5, 23.5, 23.5, 4.4, False)
    p.seg(5.5, 5.5, 22.5, 22.5, 2.2)
    return p


def offline2():
    # no network: the arcs and the dot cut by a slash, a gap either side; no crumbs
    p = offline()
    return p.clean()


def spool2():
    p = spool()
    p.rect(22, 0, 27, 6, False)
    p.seg(21.4, 6.6, 22.6, 5.4, 3.2)
    p.seg(21.8, 6.2, 22.4, 5.6, 0.9, False)
    return p


def slashed(p):
    """an "off": the picture cut by a slash from top left to bottom right, a gap either side"""
    p.seg(4.5, 4.5, 23.5, 23.5, 4.4, False)
    p.seg(5.5, 5.5, 22.5, 22.5, 2.2)
    return p


def spool4():
    # the saver is sashiko: a spool (flanges, the wound thread) and beside it the needle,
    # upright, its eye up; the thread runs from the spool over to the eye — no line through
    # anything (a line across a crest means "off")
    p = Pic()
    p.rect(4, 5, 13, 7)                      # the top flange
    p.rect(6, 8, 11, 19)                     # the thread
    for y in (10, 13, 16):
        p.rect(6, y, 11, y, False)
    p.rect(4, 20, 13, 22)                    # the bottom flange
    p.px([(4, 5), (13, 5), (4, 22), (13, 22)], False)
    p.art("""
.##.
#..#
#..#
#..#
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.##.
.#..
""", 19, 4)
    def draw(d, S):
        stroke(d, S, bez([(11.5, 8.6), (14.0, 2.0), (18.0, 2.0), (20.5, 6.0)]), 1.7)
    q = hires(draw, 0.45)
    for j in range(N):
        for i in range(N):
            p.g[j][i] = p.g[j][i] or q.g[j][i]
    return p


def offline3():
    p = wifi()
    p.seg(6.5, 6.5, 23.5, 23.5, 4.4, False)
    p.seg(7.5, 7.5, 22.5, 22.5, 2.2)
    return p.clean()


def offline4():
    # no network: the three arcs and, where the dot was, a cross
    cx, cy = M, 20.5
    p = Pic()
    for r0, r1 in ((5.0, 7.2), (9.0, 11.2), (13.0, 15.2)):
        p.sector(cx, cy, r0, r1, 45, 135)
    p.art("""
##..##
.####.
..##..
.####.
##..##
""", 11, 18)
    return p


def spool3():
    p = spool2()
    p.g[4][23] = False
    return p


FINAL = [("moon", moon_star), ("sun", sun_bars), ("lantern", lambda: toro3().shift(0, 2)),
         ("wave", lambda: wave6().shift(0, -2)), ("ethernet", ethernet), ("wifi", wifi),
         ("offline", offline4), ("bluetooth", bluetooth), ("devices", lambda: devices().shift(0, -1)),
         ("drive", drive), ("backup", lambda: chest().shift(0, -1)), ("bell", lambda: bell6().shift(0, 1)),
         ("bell-off", lambda: slashed(bell6().shift(0, 1))), ("saver", lambda: spool4().shift(0, 1)),
         ("record", lambda: record().shift(-1, 1)), ("read", read)]


CRESTS = [("moon", moon), ("moon-star", moon_star), ("sun", sun), ("lantern", lantern),
          ("wave", wave), ("ethernet", ethernet), ("wifi", wifi), ("offline", offline),
          ("bluetooth", bluetooth), ("devices", devices), ("drive", drive), ("backup", backup),
          ("bell", bell), ("bell-off", bell_off), ("saver", saver), ("record", record),
          ("read", read), ("sun-bars", sun_bars), ("sun-ring", sun_ring), ("lantern2", lantern2),
          ("lantern3", lantern3), ("wave2", wave2), ("bell2", bell2), ("bell2-off", bell2_off),
          ("saver2", saver2), ("chest", chest), ("kura2", kura2), ("lantern4", lantern4),
          ("toro", toro), ("wave3", wave3), ("bell3", bell3), ("suzu", suzu), ("saver3", saver3),
          ("wave4", wave4), ("toro2", toro2), ("bell4", bell4), ("bell4-off", bell4_off),
          ("saver4", saver4), ("saver5", saver5), ("wave6", wave6), ("toro3", toro3),
          ("bell5", bell5), ("bell5-off", bell5_off), ("spool", spool)]

THEMES = {"dark": {"ground": "181715", "accent": "eb5324", "key": "221e1a", "edge2": "3c2f22",
                   "muted": "9a8767", "select": "82241f", "tos": "f1e1b4"},
          "light": {"ground": "e8e3c2", "accent": "a84222", "key": "f8f3d8", "edge2": "d7bc8c",
                    "muted": "586459", "select": "82241f", "tos": "f8f3d8"}}   # (themes/*/panel.conf)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def crest(p, th, state):
    """a crest 44 px square as the panel draws it: on (seal, ring, picture in paper), off
    (outline, picture muted), cur (the cursor's lacquer; the seal text_on_select, picture select)"""
    t = THEMES[th]
    S, R = 44, 18
    bg = t["select"] if state == "cur" else t["ground"]
    im = Image.new("RGB", (S, S), rgb(bg))
    o = (S - 36) // 2                        # the seal: 36 px, pixels o … o+35
    cx = cy = o + R                          # its centre: the corner before pixel o+18
    for y in range(S):
        for x in range(S):
            d = math.hypot(x + .5 - cx, y + .5 - cy)
            if state in ("on", "cur"):
                if d <= R:
                    im.putpixel((x, y), rgb(t["tos"] if state == "cur" else t["accent"]))
                if R - 3 < d <= R - 2:
                    im.putpixel((x, y), rgb(t["accent"] if state == "cur" else t["key"]))
            elif R - 1 < d <= R:
                im.putpixel((x, y), rgb(t["edge2"]))
    po = cx - N // 2
    ink = {"on": t["key"], "off": t["muted"], "cur": t["select"]}[state]
    for j in range(N):
        for i in range(N):
            if p.g[j][i]:
                im.putpixel((po + i, po + j), rgb(ink))
    return im


def main():
    out = sys.argv[1]
    pics = [(n, f()) for n, f in (FINAL if "--final" in sys.argv else CRESTS)]
    if "--only" in sys.argv:
        keep = sys.argv[sys.argv.index("--only") + 1].split(",")
        pics = [(n, p) for n, p in pics if n in keep]
    for n, p in pics:
        b = p.beyond()
        x0, y0, x1, y1 = p.bbox()
        print(f"{n:10s} ink x {x0}–{x1} y {y0}–{y1} (air l{x0} r{27 - x1} t{y0} b{27 - y1})"
              + (f"  BEYOND r13: {b}" if b else "") + (f"  crumbs {p.crumbs()}" if p.crumbs() else ""))
    # zoom sheet: per crest a column — dark on, dark off, light on, light off — at 4×
    cols = len(pics)
    one = Image.new("RGB", (cols * 46, 4 * 46), (128, 128, 128))
    for c, (n, p) in enumerate(pics):
        for r, (th, st) in enumerate((("dark", "on"), ("dark", "off"), ("light", "on"), ("light", "off"))):
            one.paste(crest(p, th, st), (c * 46 + 1, r * 46 + 1))
    half = (cols + 1) // 2
    z = 4
    a = one.crop((0, 0, half * 46, 2 * 46)).resize((half * 46 * z, 2 * 46 * z), Image.NEAREST)
    b = one.crop((half * 46, 0, cols * 46, 2 * 46)).resize(((cols - half) * 46 * z, 2 * 46 * z), Image.NEAREST)
    zs = Image.new("RGB", (a.width, a.height * 2), (128, 128, 128))
    zs.paste(a, (0, 0)); zs.paste(b, (0, a.height))
    zs.save(out + "/crests-zoom.png")
    # 1× sheet (shown ×2): all states, both themes
    s1 = Image.new("RGB", (cols * 46, 6 * 46), (128, 128, 128))
    for c, (n, p) in enumerate(pics):
        for r, (th, st) in enumerate((("dark", "on"), ("dark", "off"), ("dark", "cur"),
                                      ("light", "on"), ("light", "off"), ("light", "cur"))):
            s1.paste(crest(p, th, st), (c * 46 + 1, r * 46 + 1))
    s1.resize((s1.width * 2, s1.height * 2), Image.NEAREST).save(out + "/crests-1x.png")
    if "--export" in sys.argv:
        dst = sys.argv[sys.argv.index("--export") + 1]
        with open(dst, "w", encoding="utf-8") as f:
            for n, p in pics:
                f.write(f"@{n}\n" + "\n".join(p.rows()) + "\n\n")


if __name__ == "__main__":
    main()
