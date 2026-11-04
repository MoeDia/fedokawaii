"""art.py — what the typing app draws: his keyboard and the hands on it, in the mood's inks. All of it on one
grid (a key is 20 px, the design's row), and shown at a whole multiple of it: ×1 in a small window, ×2 and ×3
in larger ones, every pixel staying a square of that size. Inks: tools/build-typing-art.py → inks.txt.

The fingers wear Wada's four papers (the prompt's: docs/design-system.md §7): little, ring, middle, index, the
same on both hands; a thumb is the parchment. A key lit and the finger that goes to it are one colour.
"""
import os

from . import canvas, keys

HERE = os.path.dirname(os.path.abspath(__file__))
KEY_W, KEY_H = 300, 100          # the keyboard, 15 × 5 keys of 20 px
HANDS_H = 84                     # the strip the hands stand in, under it: 12 of headroom, for a finger reaching
PALM_X, PALM_Y = 38, 12          # (where the palm's grid lies on the strip)
MIRROR = 270                     # the hands' mirror (twice the home row's middle: a–; on x 45 and 225)
ORDER = ('little', 'ring', 'middle', 'index')


def load_inks():
    names, dark, light = [], {}, {}
    with open(os.path.join(HERE, 'inks.txt')) as f:
        for line in f:
            if line.startswith('#'):
                continue
            t, d, lt = line.split()
            names.append(t)
            dark[t], light[t] = d, lt
    ink = {t: i + 1 for i, t in enumerate(names)}

    def pct(h):
        return b'%d;%d;%d' % tuple(round(int(h[i:i + 2], 16) * 100 / 255) for i in (0, 2, 4))
    pal = {True: {ink[t]: pct(dark[t]) for t in names}, False: {ink[t]: pct(light[t]) for t in names}}
    return ink, pal


INK, PALETTE = load_inks()
FINGER_TOKEN = ('paper_mark', 'paper_folder', 'paper_git', 'paper_time', 'gold',
                'gold', 'paper_time', 'paper_git', 'paper_folder', 'paper_mark')
FINGER_INK = tuple(INK[t] for t in FINGER_TOKEN)


def load_glyphs():
    out = {}
    with open(os.path.join(HERE, 'glyphs.txt')) as f:
        for line in f:
            if line.startswith('#'):
                continue
            c, h = line.split()
            rows = [int(h[i:i + 2], 16) for i in range(0, 28, 2)]
            ink = [x for x in range(7) if any(r >> (6 - x) & 1 for r in rows)]
            out[chr(int(c))] = (rows, ink[0], ink[-1])
    return out


GLYPHS = load_glyphs()


def word_rows(word):
    """(14 rows of column lists, width): a word in Sumi UI, its letters 7 px apart, tight at both ends"""
    if not word:
        return [[] for _ in range(14)], 0
    first = GLYPHS[word[0]][1]
    rows = [[] for _ in range(14)]
    last = 0
    for i, c in enumerate(word):
        g = GLYPHS.get(c)
        if g is None:
            continue
        for y in range(14):
            for x in range(7):
                if g[0][y] >> (6 - x) & 1:
                    rows[y].append(i * 7 + x - first)
        last = i * 7 + g[2] - first
    return rows, last + 1


class Letters:
    """The typed text in Sumi UI, on the keys' own grid: a letter's cell is 7 × 20 at 1× (its em on rows 3–16, as a
    row's words, §3), and its ground, when it has one, rows 2–17."""

    def __init__(self, k):
        self.k = k
        self.w, self.h = 7 * k, 20 * k
        self.cache = {}

    def cell(self, c, ink, ground=0):
        v = self.cache.get((c, ink, ground))
        if v is None:
            g = GLYPHS.get(c)
            rows = []
            for y in range(20):
                back = ground if 2 <= y <= 17 else 0
                line = bytearray([back]) * 7
                if g and 3 <= y <= 16:
                    bits = g[0][y - 3]
                    for x in range(7):
                        if bits >> (6 - x) & 1:
                            line[x] = ink
                rows += [[(0, canvas.scale_row(line, self.k))]] * self.k
            v = self.cache[(c, ink, ground)] = rows
        return v


class Look:
    """the inks of a key, by what is happening to it"""
    __slots__ = ('face', 'frame', 'lip', 'word')

    def __init__(self, face, frame, lip, word):
        self.face, self.frame, self.lip, self.word = face, frame, lip, word


class Keyboard:
    """The keys' states and their pictures. A key lit shows the next key to press, in its finger's paper; down
    is the real key held, so the picture moves when the keyboard does."""

    def __init__(self, dark):
        self.dark = dark
        self.lit = {}       # key → finger
        self.down = set()
        self.wrong = set()
        self.heat = {}      # key → how sure of it you are, a token: filled where it wants work, only its legend where it is yours
        self.shift = False
        self.rest = Look(INK['key'], INK['edge'], INK['edge2'], INK['muted'] if dark else INK['text'])
        self.home = Look(INK['key'], INK['edge'], INK['edge2'], INK['text'])
        self.bad = Look(INK['accent'], INK['accent_lo'], INK['accent_lo'], INK['text_on_accent'])

    def look(self, name):
        if name in self.wrong:
            return self.bad
        f = self.lit.get(name)
        if f is not None:
            return Look(FINGER_INK[f], INK['paper_ink'], INK['paper_ink'], INK['paper_ink'])
        h = self.heat.get(name)
        if h == 'asagi':
            return Look(INK['key'], INK['edge'], INK['edge2'], INK['asagi'])
        if h is not None:
            return Look(INK[h], INK['edge'], INK['edge2'], INK['ground'])
        return self.home if name in 'asdfjkl;' else self.rest

    def legend(self, name):
        p = keys.PLACE[name]
        return p[5] if self.shift else p[4]

    def key_rows(self, name):
        """the key's 20 rows at 1×: its face, frame and lip, its legend centred by its ink"""
        x, r, width, finger, _, _ = keys.PLACE[name]
        w = width * 5
        down = name in self.down
        look = self.look(name)
        face_w = w - 1                       # (a column of air between keys)
        rows = [bytearray(w) for _ in range(20)]
        top = 1 if down else 0
        for y in range(top, 18 + top):
            line = rows[y]
            line[0:face_w] = bytes([look.face]) * face_w
            line[0] = line[face_w - 1] = look.frame
        rows[top][1:face_w - 1] = bytes([look.frame]) * (face_w - 2)
        rows[17 + top][1:face_w - 1] = bytes([look.frame]) * (face_w - 2)
        rows[top][0] = rows[top][face_w - 1] = 0
        rows[17 + top][0] = rows[17 + top][face_w - 1] = 0
        if not down:
            rows[18][1:face_w - 1] = bytes([look.lip]) * (face_w - 2)
        word = self.legend(name)
        if word:
            g, gw = word_rows(word)
            gx = (face_w - gw) // 2
            for y in range(14):
                for col in g[y]:
                    rows[y + 3 + top][gx + col] = look.word
        if name in ('f', 'j'):               # (the bumps: the fingers' way home)
            rows[17 + top][face_w // 2 - 3:face_w // 2 + 4] = bytes([look.word]) * 7
        return rows

    def paint_key(self, pic, name, k, ox=0, oy=0):
        x, r, width, _, _, _ = keys.PLACE[name]
        rows = self.key_rows(name)
        out = []
        for row in rows:
            s = canvas.scale_row(row, k)
            out += [[(0, s)]] * k
        pic.clear(ox + x * 5 * k, oy + r * 20 * k, width * 5 * k, 20 * k)
        pic.spans(ox + x * 5 * k, oy + r * 20 * k, out)

    def paint(self, pic, k, ox=0, oy=0):
        for name in keys.PLACE:
            self.paint_key(pic, name, k, ox, oy)


# ── the hands ────────────────────────────────────────────────────────────────
def load_hands():
    sprites, place = {}, {}
    with open(os.path.join(HERE, 'hands.txt')) as f:
        lines = f.read().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        i += 1
        if line.startswith('place '):
            _, n, *v = line.split()
            place[n] = tuple(map(int, v))
        elif line.startswith('@'):
            name, w, h = line[1:].split()
            sprites[name] = lines[i:i + int(h)]
            i += int(h)
    return sprites, place


SPRITES, PLACES = load_hands()


def _table(mapping):
    t = bytearray(256)
    for letter, token in mapping.items():
        t[ord(letter)] = INK[token]
    return bytes(t)


SKIN = {
    True: {'o': 'lo', 'h': 'accent', 'b': 'accent', 's': 'accent_lo', 'd': 'edge2', 'k': 'lo', 'n': 'gold', 'N': 'edge2', 'i': 'edge2', 'g': 'gold', 'y': 'yellow'},
    False: {'o': 'muted', 'h': 'hi', 'b': 'hi', 's': 'key', 'd': 'edge', 'k': 'edge2', 'n': 'edge', 'N': 'edge', 'g': 'gold', 'r': 'asagi', 'e': 'teal', 'i': 'gold'},
}
SWAP = str.maketrans('hd', 'dh')


class Hands:
    """Two hands on the strip under the keyboard. pose: finger → (tip moved across, tip moved up); lit: fingers
    in their paper; pressed: fingers whose key is down."""

    def __init__(self, dark):
        self.dark = dark
        self.mood = 'oni' if dark else 'tennin'
        self.table = _table(SKIN[dark])
        self.pose = {}
        self.lit = set()
        self.pressed = set()
        self.wrong = set()

    def _lit_table(self, finger):
        token = FINGER_TOKEN[finger]
        nail = 'strong' if self.dark else 'key'
        return _table({'o': 'paper_ink', 'k': 'paper_ink', 'h': token, 'b': token, 's': token, 'd': token, 'n': nail, 'N': nail, 'g': 'paper_ink'})

    def _bad_table(self):
        return _table({'o': 'accent_lo', 'k': 'accent_lo', 'h': 'accent', 'b': 'accent', 's': 'accent', 'd': 'accent', 'n': 'text_on_accent', 'N': 'text_on_accent', 'g': 'text_on_accent'})

    def _rest_table(self, finger):
        """at rest: the nail or claw wears the finger's paper, so the colours are learned before they are needed"""
        return _table({**SKIN[self.dark], 'n': FINGER_TOKEN[finger], 'N': FINGER_TOKEN[finger]})

    def _finger(self, pic, name, finger, k, ox, oy):
        right = finger >= 5
        tx, ty, bx, by = PLACES[name]
        rows = SPRITES[f'{self.mood}.{name}']
        dx, up = self.pose.get(finger, (0, 0))
        if finger in self.pressed:
            up -= 2
        if right:
            tx, bx = MIRROR - tx, MIRROR - bx
            rows = [r[::-1].translate(SWAP) for r in rows]
        tx += dx
        n = max(len(rows) + up, 8)
        cap = min(8, len(rows) // 2)         # (the tip and its claw keep their shape; the length is the shaft's)
        table = (self._bad_table() if finger in self.wrong else self._lit_table(finger) if finger in self.lit else self._rest_table(finger))
        for i in range(n):
            src = i if i < cap else cap + (i - cap) * (len(rows) - cap) // max(n - cap, 1)
            row = rows[min(src, len(rows) - 1)]
            a = len(row) - len(row.lstrip('.'))
            b = len(row.rstrip('.'))
            if a >= b:
                continue
            ink = row[a:b].encode().translate(table)
            t = (n - 1 - i) / max(n - 1, 1)
            cx = bx + (tx - bx) * t
            x = round(cx) - len(row) // 2 + a
            y = by - n + i
            if y >= 0:                       # (a long reach stays in its strip: never onto the keys)
                pic.spans(ox, oy + y * k, [[(x * k, canvas.scale_row(ink, k))]] * k)

    def _palm(self, pic, right, k, ox, oy):
        rows = SPRITES[f'{self.mood}.palm']
        for i, row in enumerate(rows):
            if right:
                row = row[::-1].translate(SWAP)
                base = MIRROR - PALM_X - len(row) + 1
            else:
                base = PALM_X
            a = len(row) - len(row.lstrip('.'))
            b = len(row.rstrip('.'))
            if a >= b:
                continue
            ink = row[a:b].encode().translate(self.table)
            pic.spans(ox, oy + (i + PALM_Y) * k, [[((base + a) * k, canvas.scale_row(ink, k))]] * k)

    def paint(self, pic, k, ox=0, oy=0, only=None):
        """only: 'left' or 'right', when the other hand has not changed"""
        for right, fingers in ((False, (0, 1, 2, 3)), (True, (9, 8, 7, 6))):
            if only and only != ('right' if right else 'left'):
                continue
            half = MIRROR // 2 * k
            pic.clear(ox + (half if right else 0), oy, KEY_W * k - half if right else half, HANDS_H * k)
            for f, name in zip(fingers, ORDER, strict=True):
                self._finger(pic, name, f, k, ox, oy)
            self._palm(pic, right, k, ox, oy)
            self._finger(pic, 'thumb', 5 if right else 4, k, ox, oy)


class Motes:
    """What a clean run wakes on the strip of the hands, one more for every EVERY keys without a slip, MOST at a time: on the
    dark embers rising from the demon's palms, on the light petals drifting down past the angel's. A slip and they are gone.
    Their own little loop, a dozen steps a second, on 1× grid pixels."""
    EVERY, MOST = 20, 8
    STEP = 0.08
    INKS = {True: ('accent_hi', 'flame', 'accent', 'accent_lo'), False: ('gold', 'accent_hi', 'gold', 'edge2')}

    def __init__(self, dark, rng):
        self.dark, self.rng = dark, rng
        self.live = []          # [x, y, age, life, sway]
        self.wanted = 0

    def spawn(self):
        r = self.rng
        side = r.random() < 0.5
        cx = (MIRROR - 90 if side else 90) + r.randint(-26, 26)
        if self.dark:
            self.live.append([cx, 44 + r.randint(0, 10), 0, r.randint(7, 11), r.choice((-1, 0, 1))])
        else:
            self.live.append([cx, r.randint(0, 6), 0, r.randint(9, 13), r.choice((-1, 1))])

    def step(self):
        """a step of everyone's life; True if anything is there to draw"""
        for m in self.live:
            m[2] += 1
            m[1] += -2 if self.dark else 2
            if m[2] % 3 == 0:
                m[0] += m[4]
        self.live = [m for m in self.live if m[2] < m[3] and 0 <= m[1] < HANDS_H]
        if len(self.live) < self.wanted and self.rng.random() < 0.5:
            self.spawn()
        return bool(self.live)

    def paint(self, pic, k, ox, oy):
        inks = self.INKS[self.dark]
        for x, y, age, life, _ in self.live:
            ink = INK[inks[min(age * len(inks) // life, len(inks) - 1)]]
            if self.dark:
                pic.fill(ox + x * k, oy + y * k, k, k, ink)
            else:                # (a petal: two pixels, leaning)
                lean = (age // 3) % 2
                pic.fill(ox + (x + lean) * k, oy + y * k, k, k, ink)
                pic.fill(ox + (x + 1 - lean) * k, oy + (y + 1) * k, k, k, ink)


# ── seals, the eye, numbers ──────────────────────────────────────────────────
def disc(r):
    """the rows of a filled circle r across: [(offset, length)]"""
    out = []
    c = (r - 1) / 2
    for y in range(r):
        dy = y - c
        half = (c * c + c * 0.9 - dy * dy) ** 0.5 if c * c + c * 0.9 >= dy * dy else 0
        a = round(c - half)
        out.append((a, r - 2 * a))
    return out


# the mark knocked out of an earned seal: the mood's own, on a 16 × 16 grid (a flame on the dark, a lotus on the light)
SEAL_MARK = {
    True: ('................', '................', '.......#........', '.......##.......', '......###.......', '......####......',
           '.....#####......', '....#######.....', '....########....', '...#########....', '...###.##.###...', '...###.#..###...',
           '....##....##....', '.....##..##.....', '................', '................'),
    False: ('................', '................', '.......##.......', '.......##.......', '......####......', '...#..####..#...',
            '...##.####.##...', '...###.##.###...', '.#..###..###..#.', '.###.######.###.', '..###.####.###..', '...##########...',
            '.....######.....', '................', '................', '................'),
}


def paint_seal(pic, x, y, size, dark, state):
    """a seal, size px across: state 'off' a hollow ring, 'on' vermilion with its mark knocked out, 'down' the thump of
    the stamp (a pixel larger all round, lit: docs/design-system.md §11), 'gold' the gold seal"""
    ink = INK['edge2'] if state == 'off' else INK['accent_hi'] if state == 'down' else INK['gold'] if state == 'gold' else INK['accent']
    grow = 1 if state == 'down' else 0
    d = disc(size + 2 * grow)
    pic.clear(x - 2, y - 2, size + 4, size + 4)
    for i, (off, n) in enumerate(d):
        yy = y - grow + i
        if state == 'off':
            pic.fill(x - grow + off, yy, n, 1, ink)
            inner = disc(size - 2)
            if 1 <= i < size - 1:
                a, m = inner[i - 1]
                pic.fill(x + 1 + a, yy, m, 1, 0)
        else:
            pic.fill(x - grow + off, yy, n, 1, ink)
    if state != 'off':
        mark = SEAL_MARK[dark]
        k = max(size // 16, 1)
        ox, oy = x + (size - 16 * k) // 2, y + (size - 16 * k) // 2
        hole = INK['text_on_accent'] if state != 'gold' else INK['paper_ink']
        for j, row in enumerate(mark):
            for i, c in enumerate(row):
                if c == '#':
                    pic.fill(ox + i * k, oy + j * k, k, k, hole)


EYE = {     # L the lid, w the white, g the iris, k the pupil
    True: ('.......LLLLLL.......', '....LLLwwwwwwLLL....', '..LLwwwwggggwwwwLL..', '.LwwwwwgggkgwwwwwwL.', 'LwwwwwwgggkggwwwwwwL', '.LwwwwwgggkgwwwwwwL.',
           '..LLwwwwggggwwwwLL..', '....LLLwwwwwwLLL....', '.......LLLLLL.......'),
    False: ('....................', '.......LLLLLL.......', '....LLLLLLLLLLLL....', '..LLLwwwggggwwwLLL..', '.LwwwwwgggkggwwwwwL.', '..LwwwwwgggggwwwwL..',
            '....LLwwwwwwwwLL....', '.......LLLLLL.......', '....................'),
}
EYE_INKS = {True: {'L': 'accent_text', 'w': 'accent_lo', 'g': 'gold', 'k': 'lo'}, False: {'L': 'strong', 'w': 'key', 'g': 'gold', 'k': 'strong'}}


def paint_eye(pic, x, y, k, dark):
    """the eye that opens under the text (Yechiam 2003's signal): the demon's slit in gold, the angel's calm one"""
    inks = EYE_INKS[dark]
    for j, row in enumerate(EYE[dark]):
        for i, c in enumerate(row):
            if c != '.':
                pic.fill(x + i * k, y + j * k, k, k, INK[inks[c]])


def paint_word(pic, x, y, word, ink, k):
    """a word in Sumi UI at k× (display size: a whole multiple, never smoothed)"""
    for n, c in enumerate(word):
        g = GLYPHS.get(c)
        if not g:
            continue
        for yy in range(14):
            bits = g[0][yy]
            for xx in range(7):
                if bits >> (6 - xx) & 1:
                    pic.fill(x + (n * 7 + xx) * k, y + yy * k, k, k, ink)
