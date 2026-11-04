"""A pixel canvas of palette indices and its sixel writer: whole-pixel pictures in the terminal.

Pixels are one byte each, 0 the see-through one (the sixel leaves it unset: the terminal's ground
shows). Encoding runs in C by way of bytes.translate and big integers, one band of six rows and one
ink at a time, so a square's worth takes well under a millisecond and a whole board tens of ms.
"""
import re

_RUN = re.compile(rb"(.)\1{3,}", re.S)
# the ink's translate table, one per palette index: its pixels → 1, the rest → 0
_ONLY = [bytes(1 if i == c else 0 for i in range(256)) for c in range(256)]
_SHIFT = [1 << i for i in range(6)]


def _rle(m):
    run = m[0]
    return b"!%d%c" % (len(run), run[0])


class Canvas:
    __slots__ = ("w", "h", "px")

    def __init__(self, w, h, fill=0):
        self.w, self.h = w, h
        self.px = bytearray([fill]) * (w * h)

    def fill(self, x, y, w, h, ink):
        """A rectangle of one ink, clipped to the canvas."""
        x1, y1 = min(x + w, self.w), min(y + h, self.h)
        x, y = max(x, 0), max(y, 0)
        if x1 <= x or y1 <= y:
            return
        row = bytes([ink]) * (x1 - x)
        px, W = self.px, self.w
        for r in range(y, y1):
            o = r * W + x
            px[o:o + x1 - x] = row

    def dot(self, x, y, ink):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = ink

    def stamp(self, sprite, x, y, inkmap=None):
        """A sprite's opaque runs laid on the canvas, clipped. inkmap (a 256-byte table): its inks
        turned into others, as a piece's art is drawn in the mood's inks."""
        px, W, H = self.px, self.w, self.h
        for dy, runs in sprite.rows:
            r = y + dy
            if r < 0 or r >= H:
                continue
            o = r * W + x
            for dx, data in runs:
                if inkmap is not None:
                    data = data.translate(inkmap)
                a, b = x + dx, x + dx + len(data)
                if b <= 0 or a >= W:
                    continue
                if a < 0:
                    data = data[-a:]
                    a = 0
                if b > W:
                    data = data[:W - a]
                px[r * W + a:r * W + a + len(data)] = data
            _ = o

    def blit(self, other, x, y):
        """A canvas copied onto this one, its 0 pixels too (clipped)."""
        px, W, H = self.px, self.w, self.h
        ow = other.w
        w = min(ow, W - x)
        if w <= 0:
            return
        for r in range(other.h):
            ty = y + r
            if 0 <= ty < H:
                o = r * ow
                px[ty * W + x:ty * W + x + w] = other.px[o:o + w]

    def crop(self, x, y, w, h):
        out = Canvas(w, h)
        for r in range(h):
            o = (y + r) * self.w + x
            out.px[r * w:(r + 1) * w] = self.px[o:o + w]
        return out

    def scale(self, n):
        """Every pixel n × n."""
        if n == 1:
            return self
        out = Canvas(self.w * n, self.h * n)
        w = self.w
        for r in range(self.h):
            row = self.px[r * w:(r + 1) * w]
            wide = b"".join(bytes([p]) * n for p in row)
            for k in range(n):
                o = (r * n + k) * out.w
                out.px[o:o + out.w] = wide
        return out

    def sixel(self, palette, x=0, y=0, w=None, h=None):
        """The part x, y, w, h as one sixel. palette: index → (r, g, b) in whole percents."""
        w = self.w - x if w is None else w
        h = self.h - y if h is None else h
        return encode([bytes(self.px[(y + r) * self.w + x:(y + r) * self.w + x + w]) for r in range(h)], w, h, palette)


def encode(rows, w, h, palette):
    """Rows of bytes (index 0 unset) → sixel bytes: P2=1 leaves unset pixels see-through; the raster
    attributes make the picture exactly w × h; no band break after the last band."""
    out = [b'\x1bP0;1;0q"1;1;%d;%d' % (w, h)]
    inks = set()
    for row in rows:
        inks.update(row)
    inks.discard(0)
    out.extend(b"#%d;2;%d;%d;%d" % (c, *palette[c]) for c in sorted(inks))
    zero = bytes(w)
    fives = int.from_bytes(b"\x3f" * w, "little")
    only = _ONLY
    band = 0
    while band < h:
        part = rows[band:band + 6]
        if band:
            out.append(b"-")
        seen = set()
        for row in part:
            seen.update(row)
        seen.discard(0)
        first = True
        for c in sorted(seen):
            table = only[c]
            acc = 0
            for bit, row in enumerate(part):
                if row != zero:
                    t = row.translate(table)
                    if t != zero:
                        acc |= int.from_bytes(t, "little") << bit
            line = (acc + fives).to_bytes(w, "little").rstrip(b"?")
            if not first:
                out.append(b"$")
            first = False
            out.append(b"#%d" % c)
            out.append(_RUN.sub(_rle, line))
        band += 6
    out.append(b"\x1b\\")
    return b"".join(out)


class Sprite:
    """Pixel art as rows of opaque runs: [(dy, [(dx, bytes), …]), …]; w, h its box."""
    __slots__ = ("w", "h", "rows")

    def __init__(self, lines, inks):
        """lines: equal strings, a character each pixel; inks: character → palette index ('.' and
        ' ' see-through)."""
        self.h = len(lines)
        self.w = max((len(s) for s in lines), default=0)
        self.rows = []
        for dy, line in enumerate(lines):
            runs, x = [], 0
            while x < len(line):
                if line[x] in ". ":
                    x += 1
                    continue
                e = x
                data = bytearray()
                while e < len(line) and line[e] not in ". ":
                    data.append(inks[line[e]])
                    e += 1
                runs.append((x, bytes(data)))
                x = e
            if runs:
                self.rows.append((dy, runs))

    def scaled(self, n):
        """The same sprite, every pixel n × n."""
        if n == 1:
            return self
        out = Sprite([], {})
        out.w, out.h = self.w * n, self.h * n
        out.rows = []
        for dy, runs in self.rows:
            wide = [(dx * n, b"".join(bytes([p]) * n for p in data)) for dx, data in runs]
            out.rows.extend((dy * n + k, wide) for k in range(n))
        return out


def hex_percent(rgb):
    """'eb5324' → sixel's whole percents, rounded as near as they go."""
    return tuple(round(int(rgb[i:i + 2], 16) * 100 / 255) for i in (0, 2, 4))
