#!/usr/bin/env python3
"""tools/build-typing-art.py — what the typing app draws from, written into its folder:

    inks.txt    token, dark, light: the palette's tokens the app paints with (tools/wada-palette.py, the one truth)
    glyphs.txt  Sumi UI's letters as bitmaps (7 × 14): a key's legend is the desktop's own face
    hands.txt   the two pairs of hands: the demon's (dark) and the angel's (light), fingers and palm apart

    python3 -I tools/build-typing-art.py [--preview DIR]

The hands are drawn once, on the app's 1× grid (a key is 20 px): every finger a sprite of ink letters upright
(the app leans and stretches it, so that a finger can reach), and the palm with its sleeve. --preview also
writes PNGs of them at 1×, ×2 and ×3 in both moods. Needs Pillow.
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
        for c in range(33, 127):
            im = Image.new('1', (7, 14), 0)
            ImageDraw.Draw(im).text((0, 0), chr(c), fill=1, font=font)
            f.write(f'{c} ' + ''.join(f'{sum(im.getpixel((x, y)) << (6 - x) for x in range(7)):02x}' for y in range(14)) + '\n')


# ── the hands ────────────────────────────────────────────────────────────────
# A finger: its half width down its length, from the tip; drawn outward from the middle.
def finger(rows, width, knuckles, tip_round=3):
    """half widths (float) per row, tip first: rounded at the tip, swelling at the knuckles"""
    out = []
    for y in range(rows):
        t = y / max(rows - 1, 1)
        w = width / 2 * (0.86 + 0.14 * t)
        if y < tip_round:
            w *= (0.55 + 0.45 * y / tip_round)
        for k in knuckles:
            d = abs(t - k)
            if d < 0.07:
                w += 0.55 * (1 - d / 0.07)
        out.append(w)
    return out


def paint_finger(prof, shape):
    """letters from a profile. The ink letters: o outline, h light side, s skin, d dark side"""
    w = int(max(prof) * 2 + 3)
    if w % 2 == 0:
        w += 1
    mid = w // 2
    g = [['.'] * w for _ in prof]
    for y, hw in enumerate(prof):
        a, b = mid - int(round(hw)), mid + int(round(hw))
        for x in range(a, b + 1):
            g[y][x] = 's'
    # outline: skin touching no skin
    def at(x, y):
        return 0 <= y < len(g) and 0 <= x < w and g[y][x] != '.'
    o = [row[:] for row in g]
    for y in range(len(g)):
        for x in range(w):
            if g[y][x] == 's' and not (at(x - 1, y) and at(x + 1, y) and at(x, y - 1) and (at(x, y + 1) or y == len(g) - 1)):
                o[y][x] = 'o'
    # light from the upper left: the inner edge lit, the other shaded
    for y in range(len(o)):
        xs = [x for x in range(w) if o[y][x] == 's']
        if not xs:
            continue
        o[y][xs[0]] = 'h'
        if len(xs) > 3:
            o[y][xs[1]] = 'h' if shape.get('broad') else 's'
        o[y][xs[-1]] = 'd'
        if len(xs) > 5 and shape.get('broad'):
            o[y][xs[-2]] = 'd'
    return o


def crease(g, y, shape):
    """a knuckle's crease: two short lines across"""
    if not 0 <= y < len(g):
        return
    xs = [x for x, c in enumerate(g[y]) if c in 'shd']
    if len(xs) > 2:
        for x in xs[1:-1]:
            g[y][x] = 'k'


def claw(g, width):
    """the demon's: a curved hook of horn over the fingertip, rows above it added"""
    w = len(g[0])
    mid = w // 2
    top = []
    for y, hw in enumerate((0, 0.6, 1.1, 1.7, 2.2, 2.7)):
        row = ['.'] * w
        off = int(round((5 - y) * 0.35))        # (leaning in, as a hook)
        a, b = mid - int(round(hw)) + off, mid + int(round(hw)) + off
        for x in range(a, b + 1):
            if 0 <= x < w:
                row[x] = 'n'
        if b - a >= 2:
            row[a] = 'N'
        top.append(row)
    return top + g


def nail(g):
    """the angel's: a small pale almond on the fingertip"""
    for y in range(1, 5):
        xs = [x for x, c in enumerate(g[y]) if c in 'shd']
        if len(xs) > 2:
            trim = 1 if y in (1, 4) else 0
            for x in xs[trim:len(xs) - trim]:
                g[y][x] = 'n'


def mirror(g):
    return [row[::-1] for row in g]


def to_text(name, g):
    return f'@{name} {len(g[0])} {len(g)}\n' + '\n'.join(''.join(r) for r in g) + '\n'


# where each finger stands on the 1× strip, left hand (the right is its mirror round x = 135):
# tip x, tip y, base x, base y, as the home row's a s d f (their middles: 45 65 85 105)
LEFT = {'little': (45, 15, 53, 42), 'ring': (65, 6, 66, 40), 'middle': (85, 2, 79, 40), 'index': (105, 7, 92, 42), 'thumb': (122, 33, 104, 54)}


def build_hands():
    text = ['# written by tools/build-typing-art.py: @name width rows, then ink letters upright, tip first\n']
    text.append('# where each finger stands: "place NAME tipx tipy basex basey" (left hand; mirrored round x = 135)\n')
    for f, v in LEFT.items():
        text.append(f'place {f} ' + ' '.join(map(str, v)) + '\n')
    # the demon's: broad, knuckled, clawed
    for f, (tx, ty, bx, by) in LEFT.items():
        rows = by - ty
        width = {'little': 9, 'ring': 10, 'middle': 11, 'index': 11, 'thumb': 12}[f]
        prof = finger(rows, width, (0.42, 0.72) if f != 'thumb' else (0.55,))
        g = paint_finger(prof, {'broad': True})
        for k in ((0.42, 0.72) if f != 'thumb' else (0.55,)):
            crease(g, int(k * rows), {})
            crease(g, int(k * rows) + 2, {})
        g = claw(g, width)
        text.append(to_text('oni.' + f, g))
    # the angel's: slender, smooth, nails like almonds
    for f, (tx, ty, bx, by) in LEFT.items():
        rows = by - ty + 3
        width = {'little': 7, 'ring': 8, 'middle': 8, 'index': 8, 'thumb': 9}[f]
        prof = finger(rows, width, ())
        g = paint_finger(prof, {})
        crease(g, int(0.68 * rows), {})
        nail(g)
        text.append(to_text('tennin.' + f, g))
    text.append(palm('oni'))
    text.append(palm('tennin'))
    return ''.join(text)


def palm(mood):
    """the back of the hand and what the arm wears: 72 rows of the strip from x = 40, left hand"""
    im = Image.new('L', (90, 72), 0)
    d = ImageDraw.Draw(im)
    if mood == 'oni':
        d.polygon([(8, 40), (60, 38), (65, 48), (64, 56), (54, 62), (22, 62), (10, 52)], fill=255)   # the back of the hand
    else:
        d.polygon([(10, 42), (58, 40), (63, 49), (60, 56), (51, 62), (24, 62), (12, 53)], fill=255)
    px = im.load()
    g = [['.'] * 90 for _ in range(72)]
    for y in range(72):
        for x in range(90):
            if px[x, y]:
                g[y][x] = 's'
    def on(x, y):
        return 0 <= x < 90 and 0 <= y < 72 and g[y][x] != '.'
    o = [r[:] for r in g]
    for y in range(72):
        for x in range(90):
            if g[y][x] == 's' and not (on(x - 1, y) and on(x + 1, y) and on(x, y - 1) and on(x, y + 1)):
                o[y][x] = 'o'
    g = o
    # shading along the sides; knuckles as a row of creases
    for y in range(72):
        xs = [x for x in range(90) if g[y][x] == 's']
        if xs:
            g[y][xs[0]] = 'h'
            g[y][xs[-1]] = 'd'
            if mood == 'oni' and len(xs) > 8:
                g[y][xs[1]] = 'h'
                g[y][xs[-2]] = 'd'
    # the wrist and the sleeve
    x0, x1 = (22, 54) if mood == 'oni' else (24, 52)
    for y in range(60, 72):
        for x in range(x0, x1):
            if g[y][x] == '.':
                g[y][x] = 's'
        g[y][x0], g[y][x1 - 1] = 'h', 'd'
    if mood == 'oni':
        # an iron cuff, studded, then the tiger's pelt
        for y in range(61, 66):
            for x in range(x0 - 3, x1 + 3):
                g[y][x] = 'i' if y not in (61, 65) else 'o'
            for x in range(x0 + 1, x1, 7):
                g[y][x] = 'g' if y in (62, 63, 64) else g[y][x]
        for y in range(66, 72):
            for x in range(x0 - 6, x1 + 6):
                g[y][x] = 'y' if (x + y // 2) % 7 > 1 else 'o'
    else:
        # a gold bangle, then the sleeve of the feather robe with its gold edge
        for y in range(61, 64):
            for x in range(x0 - 1, x1 + 1):
                g[y][x] = 'g' if y == 62 else 'o'
        for y in range(64, 72):
            slope = (y - 64)
            for x in range(x0 - 5 - slope, x1 + 5 + slope):
                if 0 <= x < 90:
                    g[y][x] = 'r'
            for x in range(x0 - 5 - slope, x1 + 5 + slope):
                if 0 <= x < 90 and y == 64:
                    g[y][x] = 'g'
    return to_text(mood + '.palm', g)


def preview(where, text):
    sys.path.insert(0, os.path.dirname(OUT))
    os.makedirs(where, exist_ok=True)


def main(argv):
    write_inks()
    write_glyphs()
    with open(os.path.join(OUT, 'hands.txt'), 'w') as f:
        f.write(build_hands())
    if '--preview' in argv:
        preview(argv[argv.index('--preview') + 1], None)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
