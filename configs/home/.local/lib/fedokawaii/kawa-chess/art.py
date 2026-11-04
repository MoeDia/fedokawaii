"""The board as a picture: wood, the men, marks, arrows; only the squares that changed are drawn again.

One set of men drawn on a 40 × 40 grid (pieces.txt), at whole multiples only: a square of 40, 80 or
120 px is 5 × 2, 10 × 4 or 15 × 6 cells of the terminal's 8 × 20, so every square lies on the cell
grid and the wallpapers' 3 px pixel is the largest board's. Inks: inks.txt, by name, both moods.
"""
import math
import pathlib

from canvas import Canvas, Sprite, encode, hex_percent

GRID = 40            # the men's drawing grid (a square of art pixels)
KINDS = " pnbrqk"
MARGIN = 8           # the canvas beyond the squares: hairline and shadow (§4), on the left and top a pixel's air
ARROW_OFF, ARROW_HEAD, ARROW_HALF = 9, 11, 7.5   # an arrow's art: where it starts from the man's middle, its head's length and half width

# coordinates: the same 5 × 7 stroke as the bar's digits, at the art's pixel
_GLYPHS = {
    "a": ".....|.###.|....#|.####|#...#|#...#|.####",
    "b": "#....|#....|####.|#...#|#...#|#...#|####.",
    "c": ".....|.....|.###.|#...#|#....|#...#|.###.",
    "d": "....#|....#|.####|#...#|#...#|#...#|.####",
    "e": ".....|.....|.###.|#...#|#####|#....|.###.",
    "f": "..##.|.#..#|.#...|###..|.#...|.#...|.#...",
    "g": ".....|.####|#...#|#...#|.####|....#|.###.",
    "h": "#....|#....|####.|#...#|#...#|#...#|#...#",
    "0": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "1": "..#..|.##..|..#..|..#..|..#..|..#..|.###.",
    "2": ".###.|#...#|....#|...#.|..#..|.#...|#####",
    "3": ".###.|#...#|....#|..##.|....#|#...#|.###.",
    "4": "...#.|..##.|.#.#.|#..#.|#####|...#.|...#.",
    "5": "#####|#....|####.|....#|....#|#...#|.###.",
    "6": ".###.|#....|#....|####.|#...#|#...#|.###.",
    "7": "#####|....#|...#.|..#..|..#..|.#...|.#...",
    "8": ".###.|#...#|#...#|.###.|#...#|#...#|.###.",
}


class Art:
    """The inks and the drawings, read once. An ink is a palette index, the same in both moods; a
    mood is only which colour each index means."""

    def __init__(self, folder):
        self.folder = pathlib.Path(folder)
        self.index = {}
        self.pal = {"dark": {}, "light": {}}
        for line in (self.folder / "inks.txt").read_text(encoding="utf-8").splitlines():
            if line and not line.startswith("#"):
                name, dark, light = line.split()
                i = self.index[name] = len(self.index) + 1
                self.pal["dark"][i] = hex_percent(dark)
                self.pal["light"][i] = hex_percent(light)
        self.drawings = _read_blocks(self.folder / "pieces.txt")
        self.faces = _read_blocks(self.folder / "faces.txt")
        self._men = {}
        self._tex = {}

    def ink(self, name):
        return self.index[name]

    def man(self, piece, s):
        """The sprite of a piece (kind | colour << 3) at scale s."""
        key = (piece, s)
        sp = self._men.get(key)
        if sp is None:
            side = "b" if piece & 8 else "w"
            inks = {c: self.index[f"{side}_{c}"] for c in "ofldt"}
            sp = self._men[key] = Sprite(self.drawings[KINDS[piece & 7]], inks).scaled(s)
        return sp

    def face(self, name):
        """A face of the ladder as a canvas of its own, 40 × 40; None if it was never drawn."""
        lines = self.faces.get(name)
        if lines is None:
            return None
        cv = Canvas(GRID, GRID)
        cv.stamp(Sprite(lines, {c: self.index["face_" + c] for c in "oklwfdreyagbhnui"}), 0, 0)
        return cv

    def fallen(self, piece, step, s):
        """The king toppling: his drawing turned 30° a step about his foot, nearest pixel, whole art pixels."""
        key = (piece, s, "fall", step)
        sp = self._men.get(key)
        if sp is None:
            side = "b" if piece & 8 else "w"
            inks = {c: self.index[f"{side}_{c}"] for c in "ofldt"}
            lines = _turned(self.drawings[KINDS[piece & 7]], step * 30)
            sp = self._men[key] = Sprite(lines, inks).scaled(s)
        return sp

    def texture(self, seed, tone, s):
        """A square of wood at scale s: tone 'sq_l' 'sq_d' (or the last move's 'ls_l' 'ls_d'), its
        grain its own for each seed; list of rows (bytes), to lay on the canvas quickly."""
        key = (seed, tone, s)
        tx = self._tex.get(key)
        if tx is None:
            tx = self._tex[key] = _wood(self, seed, tone, s)
        return tx


def _turned(lines, degrees):
    """A 40 × 40 drawing turned to the right about its middle, and lowered as it turns so that he comes to lie on
    the square's floor; whole pixels, the nearest one."""
    a = math.radians(degrees)
    ca, sa = math.cos(a), math.sin(a)
    cx, cy = 20.0, 19.0
    drop = 9 * degrees / 90
    out = []
    for y in range(GRID):
        row = []
        for x in range(GRID):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy - drop
            sx, sy = dx * ca + dy * sa + cx, -dx * sa + dy * ca + cy
            ix, iy = int(math.floor(sx)), int(math.floor(sy))
            row.append(lines[iy][ix] if 0 <= iy < len(lines) and 0 <= ix < len(lines[iy]) else ".")
        out.append("".join(row))
    return out


def _read_blocks(path):
    out, cur = {}, None
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("@"):
            cur = line[1:].split()[0]
            out[cur] = []
        elif line.startswith("#"):
            continue
        elif cur is not None and line:
            out[cur].append(line)
    return out


def _wood(art, seed, tone, s):
    """Horizontal streaks of a darker ink, a line of light along the top and left: the same for the
    same seed, so a square never changes under a piece."""
    base, grain = art.index[tone], art.index[tone[:3] + tone[3:] + "2"]
    rows = [bytearray([base]) * GRID for _ in range(GRID)]
    x = (seed * 2654435761 + 97) & 0xffffffff
    for y in range(1, GRID - 1, 3):
        x = (x * 1103515245 + 12345) & 0x7fffffff
        if x >> 16 & 1:
            continue
        start = x >> 8 & 31
        length = 6 + (x >> 18 & 15)
        wiggle = 1 if x >> 3 & 3 == 0 else 0
        for i in range(start, min(GRID, start + length)):
            rows[min(GRID - 1, y + (wiggle if i > start + length // 2 else 0))][i] = grain
    if tone.startswith("sq"):
        lit = art.index[tone + "3"]
        for i in range(GRID):
            rows[0][i] = lit
        for r in rows:
            r[0] = lit
    wide = []
    for r in rows:
        line = b"".join(bytes([p]) * s for p in r)
        wide.extend([line] * s)
    return wide


def glyph(cv, ch, x, y, s, ink):
    """A letter or digit of the board's 5 × 7, every pixel s × s."""
    for dy, line in enumerate(_GLYPHS[ch].split("|")):
        for dx, c in enumerate(line):
            if c == "#":
                cv.fill(x + dx * s, y + dy * s, s, s, ink)


def arrow_pixels(points):
    """The art pixels of an arrow through points, its tip at the last: a shaft two pixels wide leaving the man's middle by
    ARROW_OFF, a head ARROW_HEAD long and twice ARROW_HALF across; (the arrow, the pixels round it)."""
    inside = set()
    last = len(points) - 2
    for k in range(len(points) - 1):
        (ax, ay), (bx, by) = points[k], points[k + 1]
        length = math.hypot(bx - ax, by - ay)
        ux, uy = (bx - ax) / length, (by - ay) / length
        head = ARROW_HEAD if k == last else 0
        begin = ARROW_OFF if k == 0 else -1.0
        steps = int(2 * length) + 2
        for i in range(steps):
            t = i / 2
            half = ARROW_HALF * (length - t) / ARROW_HEAD if head and t > length - head else 1.0
            reach = int(half) + 2
            for j in range(-2 * reach, 2 * reach + 1):
                # (pixels near this point of the line, each tested once by its middle)
                px = math.floor(ax + ux * t - uy * j / 2)
                py = math.floor(ay + uy * t + ux * j / 2)
                cx, cy = px + 0.5 - ax, py + 0.5 - ay
                along, across = cx * ux + cy * uy, abs(-cx * uy + cy * ux)
                if along < begin or along > length:
                    continue
                room = ARROW_HALF * (length - along) / ARROW_HEAD if head and along > length - head else 1.0
                if across < room:
                    inside.add((px, py))
    edge = set()
    for x, y in inside:
        for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if n not in inside:
                edge.add(n)
    return inside, edge


def _dot_rows(n):
    """A round dot n × n: (dy, dx, width) spans."""
    out = []
    c = (n - 1) / 2
    r2 = (n / 2) ** 2
    for y in range(n):
        xs = [x for x in range(n) if (x - c) ** 2 + (y - c) ** 2 <= r2]
        if xs:
            out.append((y, xs[0], xs[-1] - xs[0] + 1))
    return out


class BoardView:
    """A board on the screen: origin in cells, scale, which way up. set() says what should show; the
    next pictures() gives the sixels for what differs from what is on the screen."""

    def __init__(self, art, scale, mood, cw, ch, flipped=False):
        self.art, self.s, self.mood, self.cw, self.ch = art, scale, mood, cw, ch
        self.S = GRID * scale
        self.size = 8 * self.S + 2 * MARGIN
        self.cv = Canvas(self.size, self.size)
        self.flipped = flipped
        self.drawn = [None] * 64         # what each square shows on the canvas
        self.dirty = []                  # px rects to send
        self.full = True                 # (the whole picture to send)
        self.board = [0] * 64
        self.marks = {}                  # sq → set of mark names
        self.arrows = []                 # (from, to, ink name)
        self.hide = set()                # squares whose man is not drawn (it is moving)
        self.coords = True               # (the board's letters and numbers: off for the squares drill)
        self._frame()

    # ── where things are ──────────────────────────────────────────────────────────────────────
    def origin(self, sq):
        """The top-left pixel of a square on the canvas."""
        f, r = sq % 8, sq // 8
        if self.flipped:
            f, r = 7 - f, r
        else:
            r = 7 - r
        return MARGIN + f * self.S, MARGIN + r * self.S

    def at(self, x, y):
        """The square under a canvas pixel, or None."""
        f, r = (x - MARGIN) // self.S, (y - MARGIN) // self.S
        if not (0 <= f < 8 and 0 <= r < 8):
            return None
        return (7 - f) + 8 * r if self.flipped else f + 8 * (7 - r)

    def cells(self):
        """(columns, rows) the picture takes."""
        return -(-self.size // self.cw), -(-self.size // self.ch)

    # ── what should show ──────────────────────────────────────────────────────────────────────
    def set(self, board=None, marks=None, arrows=None, hide=None):
        if board is not None:
            self.board = list(board)
        if marks is not None:
            self.marks = marks
        if arrows is not None:
            self.arrows = list(arrows)
        self.hide = set() if hide is None else set(hide)

    def turn_over(self, flipped):
        if flipped != self.flipped:
            self.flipped = flipped
            self.drawn = [None] * 64

    def redraw_all(self):
        self.full = True

    def _frame(self):
        """The frame round the squares (§4): a hairline, its corners left out; two rows of shadow
        under it, each a pixel further right; a column beside it."""
        cv, ink = self.cv, self.art.index
        n, a = 8 * self.S, MARGIN - 1
        hair, sh1, sh2 = ink["hair"], ink["sh1"], ink["sh2"]
        cv.fill(a + 1, a, n, 1, hair)
        cv.fill(a + 1, a + n + 1, n, 1, hair)
        cv.fill(a, a + 1, 1, n, hair)
        cv.fill(a + n + 1, a + 1, 1, n, hair)
        cv.fill(a + 2, a + n + 2, n, 1, sh1)
        cv.fill(a + 3, a + n + 3, n, 1, sh2)
        cv.fill(a + n + 2, a + 2, 1, n, sh2)

    # ── drawing ───────────────────────────────────────────────────────────────────────────────
    def _key(self, sq):
        p = 0 if sq in self.hide else self.board[sq]
        m = self.marks.get(sq)
        return (p, tuple(sorted(m)) if m else None, self.arrows and self._arrow_sig(sq), self.coords)

    def _arrow_sig(self, sq):
        x, y = self.origin(sq)
        return tuple(a for a in self.arrows if self._touches(a, x, y)) or None

    def _touches(self, arrow, x, y):
        f, t = self.origin(arrow[0]), self.origin(arrow[1])
        S = self.S
        x0, x1 = min(f[0], t[0]), max(f[0], t[0]) + S
        y0, y1 = min(f[1], t[1]), max(f[1], t[1]) + S
        return x0 <= x < x1 and y0 <= y < y1

    def repaint(self):
        """The canvas brought up to what should show: the squares that changed."""
        changed = []
        for sq in range(64):
            k = self._key(sq)
            if self.drawn[sq] != k:
                self._square(sq)
                self.drawn[sq] = k
                changed.append(sq)
        if self.arrows and changed:
            for a in self.arrows:
                self._arrow(a)
        return changed

    def pictures(self, palette):
        """[(px x, px y, sixel)] for what changed since the last call (x, y on the cell grid)."""
        changed = self.repaint()
        if self.full or len(changed) > 20:
            self.full = False
            self.dirty.clear()
            return [(0, 0, self.cv.sixel(palette))]
        rects = [self.origin(sq) + (self.S, self.S) for sq in changed] + self.dirty
        self.dirty.clear()
        out = []
        for x, y, w, h in rects:
            out.append(self.cut(palette, x, y, w, h))
        return out

    def cut(self, palette, x, y, w, h, cv=None):
        """The part x, y, w, h grown to whole cells: (x, y, sixel)."""
        x0 = x // self.cw * self.cw
        y0 = y // self.ch * self.ch
        x1 = min(self.size, -(-(x + w) // self.cw) * self.cw)
        y1 = min(self.size, -(-(y + h) // self.ch) * self.ch)
        cv = cv or self.cv
        rows = [bytes(cv.px[r * cv.w + x0:r * cv.w + x1]) for r in range(y0, y1)]
        return x0, y0, encode(rows, x1 - x0, y1 - y0, palette)

    def _square(self, sq):
        art, s, cv = self.art, self.s, self.cv
        x, y = self.origin(sq)
        light = (sq % 8 + sq // 8) % 2 == 1
        marks = self.marks.get(sq) or ()
        tone = ("ls_l" if light else "ls_d") if "last" in marks else ("sq_l" if light else "sq_d")
        tex = art.texture(sq, tone, s)
        px, W = cv.px, cv.w
        o = y * W + x
        for row in tex:
            px[o:o + self.S] = row
            o += W
        i = art.index
        if "check" in marks:
            self._glow(x, y, i["ck_l"] if light else i["ck_d"])
        if self.coords:
            self._coords(sq, x, y, light)
        p = 0 if sq in self.hide else self.board[sq]
        if "dot" in marks and not p:
            self._dot(x, y, i["dot_l"] if light else i["dot_d"], 10)
        fall = next((int(m[4:]) for m in marks if m.startswith("fall")), 0)
        if p and fall:
            cv.stamp(art.fallen(p, fall, s), x, y)
        elif p:
            cv.stamp(art.man(p, s), x, y)
        for name in ("take", "sel", "cur", "hint", "warn", "good", "bad"):
            if name in marks:
                getattr(self, "_m_" + name)(x, y)

    def _glow(self, x, y, ink):
        """A square in check: a red bloom, dithered at the art's pixel from its middle outwards."""
        s, cv = self.s, self.cv
        for gy in range(GRID):
            for gx in range(GRID):
                d = max(abs(gx - 19.5), abs(gy - 19.5))
                if d < 8 or (d < 14 and (gx + gy) % 2 == 0) or (d < 19 and gx % 2 == 0 and gy % 2 == 0):
                    cv.fill(x + gx * s, y + gy * s, s, s, ink)

    def _coords(self, sq, x, y, light):
        """The rank on the left file's squares, the file on the bottom rank's, as they are seen."""
        f, r = sq % 8, sq // 8
        ink = self.art.index["co_l" if light else "co_d"]
        s = self.s
        if f == (7 if self.flipped else 0):
            self._glyph(str(r + 1), x + 2 * s, y + 2 * s, ink)
        if r == (7 if self.flipped else 0):
            self._glyph("abcdefgh"[f], x + self.S - 7 * s, y + self.S - 9 * s, ink)

    def _glyph(self, ch, x, y, ink):
        glyph(self.cv, ch, x, y, self.s, ink)

    def _dot(self, x, y, ink, n):
        s, cv = self.s, self.cv
        off = (GRID - n) // 2 * s
        for dy, dx, w in _dot_rows(n):
            cv.fill(x + off + dx * s, y + off + dy * s, w * s, s, ink)

    def _corners(self, x, y, ink, leg, weight):
        s, cv, S = self.s, self.cv, self.S
        L, T = leg * s, weight * s
        for ax, ay, bx, by in ((x, y, x, y), (x + S - L, y, x + S - T, y), (x, y + S - T, x, y + S - L), (x + S - L, y + S - T, x + S - T, y + S - L)):
            cv.fill(ax, ay, L, T, ink)
            cv.fill(bx, by, T, L, ink)

    def _m_take(self, x, y):
        """A man that can be taken: its four corners cut by the dot's ink."""
        s, cv, S = self.s, self.cv, self.S
        light = (self.at(x, y) % 8 + self.at(x, y) // 8) % 2 == 1
        ink = self.art.index["dot_l" if light else "dot_d"]
        n = 7
        for i in range(n):
            w = (n - i) * s
            yy = i * s
            cv.fill(x, y + yy, w, s, ink)
            cv.fill(x + S - w, y + yy, w, s, ink)
            cv.fill(x, y + S - s - yy, w, s, ink)
            cv.fill(x + S - w, y + S - s - yy, w, s, ink)

    def _m_sel(self, x, y):
        """The man picked up: the lacquer round its square."""
        s, cv, S = self.s, self.cv, self.S
        ink = self.art.index["select"]
        t = 2 * s
        cv.fill(x, y, S, t, ink)
        cv.fill(x, y + S - t, S, t, ink)
        cv.fill(x, y + t, t, S - 2 * t, ink)
        cv.fill(x + S - t, y + t, t, S - 2 * t, ink)

    def _m_cur(self, x, y):
        """The keyboard's place: the lacquer's corners, a line of its ink beside them."""
        self._corners(x, y, self.art.index["select"], 12, 3)

    def _m_hint(self, x, y):
        self._corners(x, y, self.art.index["asagi"], 14, 3)

    def _m_good(self, x, y):
        self._corners(x, y, self.art.index["asagi"], 40, 2)

    def _m_bad(self, x, y):
        self._corners(x, y, self.art.index["accent"], 40, 2)

    def _m_warn(self, x, y):
        """A man that hangs: a small red flag in its square's corner — the seal's ink, its ! in cream."""
        s, cv, S = self.s, self.cv, self.S
        i = self.art.index
        n = 11
        for k in range(n):
            cv.fill(x + S - (n - k) * s, y + k * s, (n - k) * s, s, i["accent"])
        cv.fill(x + S - 4 * s, y + 1 * s, s, 3 * s, i["on_select"])
        cv.fill(x + S - 4 * s, y + 5 * s, s, s, i["on_select"])

    def _arrow(self, arrow):
        """An arrow from a man to a square, on the art's own pixels: one ink, the men's dark round it, so that it reads on
        any square and over any man; a knight's goes round its corner, along the longer side first."""
        f, t, ink = arrow
        s = self.s

        def middle(sq):
            x, y = self.origin(sq)
            return (x - MARGIN) // s + GRID // 2, (y - MARGIN) // s + GRID // 2

        a, b = middle(f), middle(t)
        dx, dy = abs(a[0] - b[0]) // GRID, abs(a[1] - b[1]) // GRID
        points = [a, b]
        if sorted((dx, dy)) == [1, 2]:
            points = [a, (a[0], b[1]) if dy == 2 else (b[0], a[1]), b]
        inside, edge = arrow_pixels(points)
        i, cv = self.art.index, self.cv
        for ps, colour in ((edge, i["b_o"]), (inside, i[ink])):
            for gx, gy in ps:
                cv.fill(MARGIN + gx * s, MARGIN + gy * s, s, s, colour)

    # ── a man in motion ───────────────────────────────────────────────────────────────────────
    def under(self):
        """A copy of the board as it stands: the ground a moving man is drawn over."""
        c = Canvas(self.size, self.size)
        c.px[:] = self.cv.px
        return c

    def moving(self, ground, piece, x, y, last, palette):
        """The frame of a man at x, y over ground: (x, y, sixel) for his old and new place together."""
        S = self.S
        x0, y0 = min(x, last[0]), min(y, last[1])
        x1, y1 = max(x, last[0]) + S, max(y, last[1]) + S
        fx0 = x0 // self.cw * self.cw
        fy0 = y0 // self.ch * self.ch
        fx1 = min(self.size, -(-x1 // self.cw) * self.cw)
        fy1 = min(self.size, -(-y1 // self.ch) * self.ch)
        part = ground.crop(fx0, fy0, fx1 - fx0, fy1 - fy0)
        part.stamp(self.art.man(piece, self.s), x - fx0, y - fy0)
        return fx0, fy0, part.sixel(palette)


