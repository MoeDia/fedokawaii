#!/usr/bin/env python3
"""tools/audit-pads.py — the audit's first numbers for every surface the gallery shot (T19m (b)):
inside each surface's frame (its box from boxes.json, less the 1 px hairline and the shadow's two rows
and one column), the content's ink box and the paper left round it — left, right, top, bottom — in
both moods, and whether the two moods agree. A panel's pads are 16 (docs/design-system.md §4); a
mismatch between the moods, or left ≠ right where the content is centred, is a finding to look at.

    python3 -I tools/audit-pads.py GALLERY_DIR [--json]

GALLERY_DIR is tools/gallery.sh's --out (boxes.json, dark/NAME.png, light/NAME.png). Ink = a pixel
more than 40 (summed over R, G, B) from the commonest colour inside the frame. Exit 0 · 2 misuse.
"""
import json
import sys

from PIL import Image


def pads(img, box):
    x0, y0, x1, y1 = box
    # (the box's ends are exclusive; the frame is the box less its shadow — one column right, two
    # rows under; the paper is inside the hairline)
    fx0, fy0, fx1, fy1 = x0, y0, x1 - 2, y1 - 3
    ix0, iy0, ix1, iy1 = fx0 + 1, fy0 + 1, fx1 - 1, fy1 - 1
    if ix1 <= ix0 or iy1 <= iy0:
        return None
    region = img.crop((ix0, iy0, ix1 + 1, iy1 + 1))
    px = region.load()
    w, h = region.size
    ground = max(region.getcolors(w * h))[1]
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if abs(p[0] - ground[0]) + abs(p[1] - ground[1]) + abs(p[2] - ground[2]) > 40:
                xs.append(x)
                ys.append(y)
    if not xs:
        return {'empty': True}
    return {'left': min(xs), 'right': w - 1 - max(xs), 'top': min(ys), 'bottom': h - 1 - max(ys),
            'inside': [w, h], 'ground': '#%02x%02x%02x' % ground[:3]}


def main(argv):
    if not argv or argv[0].startswith('-'):
        print(__doc__, file=sys.stderr)
        return 2
    root = argv[0].rstrip('/')
    boxes = json.load(open(f'{root}/boxes.json'))
    out = {}
    for name, moods in sorted(boxes.items()):
        if name == 'bar':
            continue                                   # (the bar has its own check: bar-geometry.sh)
        row = {}
        for mood in ('dark', 'light'):
            if mood in moods:
                img = Image.open(f'{root}/{mood}/{name}.png').convert('RGB')
                row[mood] = pads(img, moods[mood])
        out[name] = row
    if '--json' in argv:
        print(json.dumps(out, indent=1))
        return 0
    print(f'{"surface":<16} {"mood":<5} {"left":>4} {"right":>5} {"top":>4} {"bottom":>6}  inside')
    for name, row in out.items():
        for mood, p in row.items():
            if not p or p.get('empty'):
                print(f'{name:<16} {mood:<5} (nothing inside)')
                continue
            print(f'{name:<16} {mood:<5} {p["left"]:>4} {p["right"]:>5} {p["top"]:>4} {p["bottom"]:>6}  '
                  f'{p["inside"][0]}×{p["inside"][1]}')
        d, l = row.get('dark'), row.get('light')
        if d and l and not d.get('empty') and not l.get('empty'):
            if any(d[k] != l[k] for k in ('left', 'right', 'top', 'bottom')):
                print(f'{"":<16} ↑ the moods differ')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
