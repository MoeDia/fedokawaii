"""canvas.py — pictures in the terminal: a grid of ink numbers kept in memory, sent to foot as sixels in
tiles, and only the tiles that changed. Ink 0 is no ink: the window's own ground shows there.

A tile is a cell-aligned rectangle (8 cells wide, as many rows as make a height both the cell's and a
sixel band's multiple), so foot never has to cut one image with another, and a tile changed costs a few
hundred bytes however large the picture is. A tile is erased before it is sent again: foot blends a
transparent sixel over what lay there, so a pixel that went back to no ink would stay.
"""
import math
import re

TO_SIXEL = bytes(min(i + 63, 126) for i in range(256))
RUNS = re.compile(rb'(.)\1{3,}', re.S)
_bits = {}


def _masks(ink):
    """the six tables that turn a row's ink numbers into that row's bit in a sixel, for one ink"""
    m = _bits.get(ink)
    if m is None:
        m = _bits[ink] = [bytes(1 << i if v == ink else 0 for v in range(256)) for i in range(6)]
    return m


def _run(m):
    return b'!%d%c' % (len(m[0]), m[1][0])


def sixel(rows, palette):
    """rows: the picture's rows as bytes of ink numbers, all alike wide. palette: ink number → b'r;g;b'
    (percents). The sixel, as bytes: unset pixels stay unset (P2 = 1), no band break after the last."""
    w = len(rows[0])
    head = [b'\x1bP0;1;0q"1;1;%d;%d' % (w, len(rows))]
    body = []
    used = set()
    for y in range(0, len(rows), 6):
        band = rows[y:y + 6]
        inks = set()
        for r in band:
            inks.update(r)
        inks.discard(0)
        parts = []
        for ink in sorted(inks):
            masks = _masks(ink)
            acc = 0
            for i, r in enumerate(band):
                acc |= int.from_bytes(r.translate(masks[i]), 'little')
            s = acc.to_bytes(w, 'little').translate(TO_SIXEL).rstrip(b'?')
            parts.append(b'#%d%s' % (ink, RUNS.sub(_run, s)))
        used |= inks
        body.append(b'$'.join(parts))
    head.extend(b'#%d;2;%s' % (i, palette[i]) for i in sorted(used))
    return b''.join(head) + b'-'.join(body) + b'\x1b\\'


class Picture:
    """w × h pixels of ink numbers, at a place on the screen: a grid of tiles, and the ones not yet sent"""

    def __init__(self, w, h, cell):
        self.w, self.h = w, h
        self.cw, self.ch = cell
        self.rows = [bytearray(w) for _ in range(h)]
        self.tile_w = 8 * self.cw
        self.tile_h = math.lcm(self.ch, 6)
        self.cols = math.ceil(w / self.tile_w)
        self.tiles_y = math.ceil(h / self.tile_h)
        self.dirty = set()
        self.touch_all()

    def touch_all(self):
        self.dirty = {(i, j) for i in range(self.cols) for j in range(self.tiles_y)}

    def _touch(self, x0, y0, x1, y1):
        tw, th = self.tile_w, self.tile_h
        for j in range(y0 // th, (y1 - 1) // th + 1):
            for i in range(x0 // tw, (x1 - 1) // tw + 1):
                self.dirty.add((i, j))

    def clear(self, x=0, y=0, w=None, h=None):
        w = self.w - x if w is None else w
        h = self.h - y if h is None else h
        x, y, x1, y1 = max(x, 0), max(y, 0), min(x + w, self.w), min(y + h, self.h)
        if x >= x1 or y >= y1:
            return
        blank = bytes(x1 - x)
        for r in self.rows[y:y1]:
            r[x:x1] = blank
        self._touch(x, y, x1, y1)

    def fill(self, x, y, w, h, ink):
        x, y, x1, y1 = max(x, 0), max(y, 0), min(x + w, self.w), min(y + h, self.h)
        if x >= x1 or y >= y1:
            return
        line = bytes([ink]) * (x1 - x)
        for r in self.rows[y:y1]:
            r[x:x1] = line
        self._touch(x, y, x1, y1)

    def spans(self, x, y, spans):
        """spans: for each row from y down, a list of (offset, bytes): what it paints, nothing between"""
        lo, hi, top, bottom = self.w, 0, self.h, 0
        for dy, row in enumerate(spans):
            yy = y + dy
            if not 0 <= yy < self.h:
                continue
            r = self.rows[yy]
            for off, ink in row:
                a, b = x + off, x + off + len(ink)
                if a < 0:
                    ink, a = ink[-a:], 0
                if b > self.w:
                    ink, b = ink[:self.w - b], self.w
                if a < b:
                    r[a:b] = ink
                    lo, hi, top, bottom = min(lo, a), max(hi, b), min(top, yy), max(bottom, yy + 1)
        if lo < hi and top < bottom:
            self._touch(lo, top, hi, bottom)

    def send(self, col, row, palette):
        """every tile not yet sent, as bytes for the terminal (col, row: the picture's corner, from 1)"""
        out = []
        tw, th = self.tile_w, self.tile_h
        cells = 8
        lines = th // self.ch
        for i, j in sorted(self.dirty):
            x0, x1 = i * tw, min((i + 1) * tw, self.w)
            y0, y1 = j * th, min((j + 1) * th, self.h)
            r0, c0 = row + j * lines, col + i * cells
            for k in range(lines):
                out.append(b'\x1b[%d;%dH\x1b[%dX' % (r0 + k, c0, cells))
            tile = [bytes(r[x0:x1]) for r in self.rows[y0:y1]]
            if any(any(t) for t in tile):
                out.append(b'\x1b[%d;%dH' % (r0, c0))
                out.append(sixel(tile, palette))
        self.dirty.clear()
        return b''.join(out)


def scale_row(row, k):
    """a row of ink numbers, each pixel k wide (extended slices: no Python per pixel)"""
    if k == 1:
        return bytes(row)
    out = bytearray(len(row) * k)
    for i in range(k):
        out[i::k] = row
    return bytes(out)
