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
HANDS_H = 72                     # the strip the hands stand in, under it
MIRROR = 270                     # the hands' mirror (twice the home row's middle: a–; on x 45 and 225)
ORDER = ('little', 'ring', 'middle', 'index')


def load_inks():
    names, dark, light = [], {}, {}
    with open(os.path.join(HERE, 'inks.txt')) as f:
        for line in f:
            if line.startswith('#'):
                continue
            t, d, l = line.split()
            names.append(t)
            dark[t], light[t] = d, l
    ink = {t: i + 1 for i, t in enumerate(names)}

    def pct(h):
        return b'%d;%d;%d' % tuple(round(int(h[i:i + 2], 16) * 100 / 255) for i in (0, 2, 4))
    pal = {True: {ink[t]: pct(dark[t]) for t in names}, False: {ink[t]: pct(light[t]) for t in names}}
    return ink, pal


INK, PALETTE = load_inks()
FINGER_INK = tuple(INK[t] for t in ('paper_mark', 'paper_folder', 'paper_git', 'paper_time', 'lit',
                                    'lit', 'paper_time', 'paper_git', 'paper_folder', 'paper_mark'))


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
        self.heat = {}      # key → an ink (the progress page's)
        self.shift = False
        self.rest = Look(INK['key'], INK['edge'], INK['edge2'], INK['muted'] if dark else INK['text'])
        self.home = Look(INK['key'], INK['edge'], INK['edge2'], INK['text'])
        self.bad = Look(INK['accent'], INK['accent_lo'], INK['accent_lo'], INK['text_on_accent'])

    def look(self, name):
        if name in self.wrong:
            return self.bad
        f = self.lit.get(name)
        if f is not None:
            return Look(FINGER_INK[f], INK['paper_ink'], INK['paper_ink'], INK['paper_ink'] if f not in (4, 5) else INK['lit_text'])
        h = self.heat.get(name)
        if h is not None:
            return Look(h, INK['edge'], INK['edge2'], INK['ground'])
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
            rows[15 + top][face_w // 2 - 2:face_w // 2 + 3] = bytes([look.word]) * 5
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
    True: {'o': 'lo', 'h': 'accent', 's': 'accent_lo', 'd': 'edge2', 'k': 'lo', 'n': 'gold', 'N': 'strong', 'i': 'edge2', 'g': 'gold', 'y': 'yellow'},
    False: {'o': 'muted', 'h': 'key', 's': 'key', 'd': 'edge', 'k': 'edge2', 'n': 'hi', 'N': 'hi', 'g': 'gold', 'r': 'asagi', 'i': 'gold'},
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
        ink = FINGER_INK[finger]
        token = {v: k for k, v in INK.items()}[ink]
        return _table({'o': 'paper_ink', 'k': 'paper_ink', 'h': token, 's': token, 'd': token, 'n': 'paper_ink', 'N': 'paper_ink'})

    def _bad_table(self):
        return _table({'o': 'accent_lo', 'k': 'accent_lo', 'h': 'accent', 's': 'accent', 'd': 'accent', 'n': 'text_on_accent', 'N': 'text_on_accent'})

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
        table = (self._bad_table() if finger in self.wrong else self._lit_table(finger) if finger in self.lit else self.table)
        out = []
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
            spans = [[((x * k), canvas.scale_row(ink, k))]] * k
            pic.spans(ox, oy + (by - n + i) * k, spans)

    def _palm(self, pic, right, k, ox, oy):
        rows = SPRITES[f'{self.mood}.palm']
        x0 = 40
        for i, row in enumerate(rows):
            if right:
                row = row[::-1].translate(SWAP)
                base = MIRROR - x0 - len(row) + 1
            else:
                base = x0
            a = len(row) - len(row.lstrip('.'))
            b = len(row.rstrip('.'))
            if a >= b:
                continue
            ink = row[a:b].encode().translate(self.table)
            pic.spans(ox, oy + i * k, [[((base + a) * k, canvas.scale_row(ink, k))]] * k)

    def paint(self, pic, k, ox=0, oy=0, only=None):
        """only: 'left' or 'right', when the other hand has not changed"""
        for right, fingers in ((False, (0, 1, 2, 3)), (True, (9, 8, 7, 6))):
            if only and only != ('right' if right else 'left'):
                continue
            half = MIRROR // 2 * k
            pic.clear(ox + (half if right else 0), oy, KEY_W * k - half if right else half, HANDS_H * k)
            for f, name in zip(fingers, ORDER):
                self._finger(pic, name, f, k, ox, oy)
            self._palm(pic, right, k, ox, oy)
            self._finger(pic, 'thumb', 5 if right else 4, k, ox, oy)
