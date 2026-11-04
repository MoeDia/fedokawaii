#!/usr/bin/env python3
"""tools/build-typing-art.py — what the typing app draws from, written into its folder:

    inks.txt    token, dark, light: the palette's tokens the app paints with (tools/wada-palette.py, the one truth)
    glyphs.txt  Sumi UI's letters as bitmaps (7 × 14): a key's legend is the desktop's own face
    hands.txt   the two pairs of hands: the demon's (dark) and the angel's (light), fingers and palm apart

    python3 -I tools/build-typing-art.py

The hands are drawn once, on the app's 1× grid (a key is 20 px): every finger a sprite of ink letters upright
(the app leans and stretches it, so that a finger can reach), and the palm with its sleeve. Needs Pillow.
"""
import importlib.util
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'configs/home/.local/lib/fedokawaii/kawatype')
TOKENS = ('ground', 'surface', 'key', 'edge', 'edge2', 'hi', 'lo', 'faint', 'muted', 'text', 'strong', 'accent', 'accent_hi',
          'accent_lo', 'accent_text', 'text_on_accent', 'select', 'text_on_select', 'select_lo', 'lit', 'lit_text', 'asagi', 'flame',
          'gold', 'yellow', 'teal', 'paper_mark', 'paper_folder', 'paper_git', 'paper_time')


def palette():
    spec = importlib.util.spec_from_file_location('wada', os.path.join(ROOT, 'tools/wada-palette.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m.palette()[0]


def write_inks():
    p = palette()
    with open(os.path.join(OUT, 'inks.txt'), 'w') as f:
        f.write('# written by tools/build-typing-art.py from tools/wada-palette.py: token dark light\n')
        for t in TOKENS:
            f.write(f'{t} {p["dark"][t]} {p["light"][t]}\n')
        f.write(f'paper_ink {p["dark"]["lo"]} {p["light"]["strong"]}\n')   # (the ink on the four papers: foot's colour 30)


def write_glyphs():
    font = ImageFont.truetype(os.path.join(ROOT, 'system/fonts/SumiUI.ttf'), 14)
    with open(os.path.join(OUT, 'glyphs.txt'), 'w') as f:
        f.write('# written by tools/build-typing-art.py: Sumi UI at 14 px, ASCII; the code, then 14 rows of 7 bits in hex\n')
        for c in [*range(33, 127), ord('·'), ord('↵')]:
            im = Image.new('1', (7, 14), 0)
            ImageDraw.Draw(im).text((0, 0), chr(c), fill=1, font=font)
            f.write(f'{c} ' + ''.join(f'{sum(im.getpixel((x, y)) << (6 - x) for x in range(7)):02x}' for y in range(14)) + '\n')


# ── the hands ────────────────────────────────────────────────────────────────
# Each finger a sprite upright, tip first, in ink letters; the app leans it from its base to its tip.
#   o outline   h the lit side   s skin   d the shaded side   b a lit knuckle   k a crease   n nail or claw (the finger's paper)
#   N the claw's dark side       g gold   i iron               y the tiger's pelt   r the robe   e the robe's dark side
# Light falls from the upper left on both hands (docs/design-system.md §4: the bar's shadow): when the app mirrors
# the right hand it swaps h and d.
def profile(rows, base_w, tip_w, knuckles=(), bulge=0.8, round_rows=4):
    """half widths down a finger, tip first"""
    out = []
    for y in range(rows):
        t = y / max(rows - 1, 1)
        w = (tip_w + (base_w - tip_w) * t) / 2
        if y < round_rows:
            w *= (0.5 + 0.5 * (y + 0.5) / round_rows) ** 0.8
        for k in knuckles:
            d = abs(t - k)
            if d < 0.09:
                w += bulge * (1 - d / 0.09)
        out.append(w)
    return out


def shape(prof):
    """the skin's cells from half widths, on a grid wide enough, odd, its middle the finger's axis"""
    w = int(max(prof) * 2 + 3) | 1
    mid = w // 2
    g = [['.'] * w for _ in prof]
    for y, hw in enumerate(prof):
        a, b = mid - round(hw), mid + round(hw)
        for x in range(max(a, 0), min(b + 1, w)):
            g[y][x] = 's'
    return g


def outlined(g, open_below=True):
    """the outermost skin becomes the outline; open at the foot, where the palm covers it"""
    h, w = len(g), len(g[0])
    def on(x, y):
        return 0 <= y < h and 0 <= x < w and g[y][x] != '.' or (open_below and y >= h)
    o = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] != '.' and not (on(x - 1, y) and on(x + 1, y) and on(x, y - 1) and on(x, y + 1)):
                o[y][x] = 'o'
    return o


def shaded(g, lit=1, dark=1):
    for row in g:
        xs = [x for x, c in enumerate(row) if c == 's']
        if len(xs) > lit + dark:
            for x in xs[:lit]:
                row[x] = 'h'
            for x in xs[len(xs) - dark:]:
                row[x] = 'd'
    return g


def crease(g, y, inset=1, length=None):
    if 0 <= y < len(g):
        xs = [x for x, c in enumerate(g[y]) if c in 'shd']
        xs = xs[inset:len(xs) - inset] if len(xs) > 2 * inset else xs
        for x in xs[:length]:
            g[y][x] = 'k'


def oni_claw(g):
    """a hooked claw of horn grown out of the fingertip"""
    w = len(g[0])
    mid = w // 2
    top = []
    widths = (0.0, 0.5, 1.0, 1.5, 1.9, 2.3, 2.7)
    for y, hw in enumerate(widths):
        row = ['.'] * w
        lean = (len(widths) - 1 - y) * 0.45                # (hooked inward at its point)
        a, b = mid - round(hw) + round(lean), mid + round(hw) + round(lean)
        for x in range(max(a, 0), min(b + 1, w)):
            row[x] = 'n'
        if b - a >= 1 and b < w:
            row[b] = 'N'
        top.append(row)
    return top + g


def oni_finger(rows, base_w, tip_w, knuckles):
    g = outlined(shape(profile(rows, base_w, tip_w, knuckles, bulge=0.9)))
    g = shaded(g, lit=2, dark=2)
    for k in knuckles:
        y = int(k * (rows - 1))
        crease(g, y - 1, 2)
        crease(g, y + 1, 2)
        # (the knuckle catches the torch)
        xs = [x for x, c in enumerate(g[y]) if c in 'shd']
        for x in xs[2:len(xs) // 2 + 1]:
            g[y][x] = 'b'
    return oni_claw(g)


def tennin_finger(rows, base_w, tip_w, ring=False):
    g = outlined(shape(profile(rows, base_w, tip_w, (), round_rows=5)))
    g = shaded(g, lit=0, dark=1)
    # the nail: an almond of the finger's paper
    for y, inset in ((1, 2), (2, 1), (3, 1), (4, 1), (5, 2)):
        xs = [x for x, c in enumerate(g[y]) if c in 'shd']
        for x in xs[inset - 1:len(xs) - inset + 1]:
            if 0 < x < len(g[y]) - 1:
                g[y][x] = 'n'
    for k in (0.42, 0.68):
        crease(g, int(k * (rows - 1)), 2, 3)
    if ring:
        y = int(0.8 * (rows - 1))
        for yy in (y, y + 1):
            xs = [x for x, c in enumerate(g[yy]) if c in 'shd']
            for x in xs:
                g[yy][x] = 'g'
    return g


def to_text(name, g):
    return f'@{name} {len(g[0])} {len(g)}\n' + '\n'.join(''.join(r) for r in g) + '\n'


# where each finger stands on the 1× strip, left hand (the right is its mirror round x = 135):
# tip x, tip y, base x, base y; the tips over the home row's a s d f (their middles: 45 65 85 105)
OFFSET = 12            # (the headroom above the hands: a finger reaches up into it)
LEFT = {'little': (45, 16, 54, 44), 'ring': (65, 6, 66, 42), 'middle': (85, 2, 79, 42), 'index': (105, 7, 92, 44), 'thumb': (123, 34, 103, 58)}


def build_hands():
    text = ['# written by tools/build-typing-art.py: @name width rows, then ink letters upright, tip first\n',
            '# where each finger stands: "place NAME tipx tipy basex basey" (left hand; mirrored round x = 135)\n']
    for f, (tx, ty, bx, by) in LEFT.items():
        text.append(f'place {f} {tx} {ty + OFFSET} {bx} {by + OFFSET}\n')
    for f, (_, ty, _, by) in LEFT.items():
        rows = by - ty - 1
        base, tip = {'little': (11, 8), 'ring': (13, 9), 'middle': (14, 10), 'index': (14, 10), 'thumb': (16, 11)}[f]
        text.append(to_text('oni.' + f, oni_finger(rows, base, tip, (0.34, 0.68) if f != 'thumb' else (0.5,))))
    for f, (_, ty, _, by) in LEFT.items():
        rows = by - ty + 2
        base, tip = {'little': (9, 5), 'ring': (10, 6), 'middle': (10, 6), 'index': (10, 6), 'thumb': (11, 7)}[f]
        text.append(to_text('tennin.' + f, tennin_finger(rows, base, tip, ring=f == 'ring')))
    text.append(palm('oni'))
    text.append(palm('tennin'))
    return ''.join(text)


PALM_W, PALM_H, PALM_X = 92, 72, 38     # (its grid: on the strip from x = PALM_X, y = OFFSET)


def palm(mood):
    """the back of the hand and what the arm wears, left hand"""
    W, H = PALM_W, PALM_H
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    if mood == 'oni':
        d.polygon([(12, 39), (26, 36), (46, 36), (60, 38), (69, 46), (68, 54), (58, 60), (56, 66), (24, 66), (20, 58), (12, 50)], fill=255)
    else:
        d.polygon([(15, 41), (28, 38), (46, 38), (58, 40), (65, 48), (62, 56), (54, 61), (52, 66), (28, 66), (24, 59), (15, 51)], fill=255)
    px = im.load()
    g = [['s' if px[x, y] else '.' for x in range(W)] for y in range(H)]
    g = outlined(g, open_below=False)
    if mood == 'oni':
        g = shaded(g, lit=2, dark=3)
        # four knuckles along its top, each lit from the left; a vein or two
        for kx in (17, 30, 42, 54):
            for y, x0, x1 in ((39, kx, kx + 6), (40, kx - 1, kx + 7), (41, kx - 1, kx + 7), (42, kx, kx + 6)):
                for x in range(x0, x1):
                    if g[y][x] in 'shd':
                        g[y][x] = 'b' if x < kx + 3 else 's'
            for y in (44,):
                for x in range(kx + 1, kx + 6):
                    if g[y][x] in 'shd':
                        g[y][x] = 'k'
        for (x, y) in ((31, 49), (32, 50), (33, 51), (34, 52), (35, 53), (47, 48), (46, 49), (45, 50), (44, 51), (43, 52), (43, 53)):
            if g[y][x] == 's':
                g[y][x] = 'k'
    else:
        g = shaded(g, lit=0, dark=2)
        for kx in (21, 33, 44):
            for x in range(kx, kx + 3):
                if g[43][x] in 'shd':
                    g[43][x] = 'k'
    if mood == 'oni':
        # an iron cuff with gold studs, then the tiger's pelt, torn at the edge
        x0, x1 = 19, 62
        for y in range(59, 65):
            for x in range(x0, x1):
                g[y][x] = 'o' if y in (59, 64) or x in (x0, x1 - 1) else 'i'
        for x in range(x0 + 3, x1 - 3, 6):
            g[61][x] = g[62][x] = g[61][x + 1] = g[62][x + 1] = 'g'
        for y in range(65, 72):
            a, b = x0 - 2 - (y - 65) // 2, x1 + 1 + (y - 65) // 2
            for x in range(a, b):
                stripe = (x + (y // 2)) % 8
                g[y][x] = 'o' if stripe < 2 else 'y'
    else:
        # three gold bangles, then the sleeve of the feather robe, opening as it falls, gold at its hem
        x0, x1 = 24, 54
        for y in range(60, 65):
            for x in range(x0 - (1 if y % 2 else 0), x1 + (1 if y % 2 else 0)):
                g[y][x] = 'g' if y % 2 else 'o'
        for y in range(65, 72):
            a, b = x0 - 3 - (y - 65) * 2, x1 + 3 + (y - 65) * 2
            for x in range(max(a, 0), min(b, W)):
                g[y][x] = 'r'
            if a >= 0:
                g[y][a] = g[y][a + 1] = 'g'
            if b <= W:
                g[y][b - 1] = g[y][b - 2] = 'g'
            for x in range(a + 5, b - 5, 11):      # (a crease of the silk)
                if 0 <= x < W and g[y][x] == 'r':
                    g[y][x] = 'e'
    return to_text(mood + '.palm', g)


def main():
    write_inks()
    write_glyphs()
    with open(os.path.join(OUT, 'hands.txt'), 'w') as f:
        f.write(build_hands())
    return 0


if __name__ == '__main__':
    sys.exit(main())
