#!/usr/bin/env python3
"""tools/px.py — measure a screenshot to the pixel (the design is checked by numbers, not by eye).

  px.py runs   IMG (row Y | col X) [--region R]      colour runs along a row or column: the
                                                      exact stripes (the bar's 27 rows, a frame)
  px.py boxes  IMG [--region R] [--bg C] [--min N]   ink bounding boxes (8-connected, not the
                                                      background), left to right, top to bottom
  px.py gaps   IMG (x | y) [--region R] [--bg C]      the ink spans along an axis and the gaps
                                                      between them (the bar's tiles: 8/4/10/6)
  px.py centre IMG [--region R] [--bg C]             where the ink's centre lies against the
                                                      region's: dx dy (0 0 = centred, .5 = off by half)
  px.py hist   IMG [--region R] [--top N]            the colours and how many pixels each
  px.py diff   A B [--tol N] [--out PNG]              pixels differing by more than N per channel:
                                                      count, bounding box (a picture of them)
  px.py zoom   IMG R SCALE OUT                        a crop, each pixel a SCALE×SCALE square

R is x,y,w,h; C a colour as #rrggbb, or "auto" (the commonest colour of the region: default).
--json prints the result as JSON. Exit 0 · 1 the image cannot be read · 2 misuse.
"""
import json
import sys

try:
    import numpy as np
    from PIL import Image
    from scipy import ndimage
except ImportError as e:            # (python3-pillow, python3-numpy, python3-scipy)
    print(f"px: {e}", file=sys.stderr)
    sys.exit(1)


def load(path):
    try:
        return np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    except (OSError, ValueError) as e:
        print(f"px: {path}: {e}", file=sys.stderr)
        sys.exit(1)


def hexc(c):
    return "#%02x%02x%02x" % tuple(int(v) for v in c)


def parse_colour(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.int16)


def region(img, spec):
    if not spec:
        return img, 0, 0
    x, y, w, h = (int(v) for v in spec.split(","))
    return img[y:y + h, x:x + w], x, y


def background(a, spec):
    if spec and spec != "auto":
        return parse_colour(spec)
    flat = a.reshape(-1, 3)
    cols, counts = np.unique(flat, axis=0, return_counts=True)
    return cols[counts.argmax()]


def ink_mask(a, bg):
    return np.any(a != bg, axis=2)


def runs(line):
    out, start = [], 0
    for i in range(1, len(line) + 1):
        if i == len(line) or not np.array_equal(line[i], line[start]):
            out.append({"from": start, "len": i - start, "colour": hexc(line[start])})
            start = i
    return out


def boxes(mask, minpix):
    lab, _ = ndimage.label(mask, structure=np.ones((3, 3), dtype=int))     # (8-connected)
    counts = np.bincount(lab.ravel())
    found = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None or counts[i] < minpix:
            continue
        ys, xs = sl
        found.append({"x": xs.start, "y": ys.start, "w": xs.stop - xs.start, "h": ys.stop - ys.start,
                      "pixels": int(counts[i])})
    found.sort(key=lambda b: (b["y"], b["x"]))
    return found


def spans(mask, axis):
    present = mask.any(axis=0 if axis == "x" else 1)
    out, i = [], 0
    while i < len(present):
        if present[i]:
            j = i
            while j < len(present) and present[j]:
                j += 1
            out.append((i, j - i))
            i = j
        else:
            i += 1
    return out


def opt(args, name, default=None):
    if name in args:
        k = args.index(name)
        if k + 1 < len(args):
            return args[k + 1]
    return default


def main(argv):
    args = argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args else 2
    cmd, as_json = args[0], "--json" in args
    res = None
    try:
        if cmd == "runs":
            img = load(args[1])
            a, ox, oy = region(img, opt(args, "--region"))
            k = int(args[3])
            line = a[k - oy] if args[2] == "row" else a[:, k - ox]
            res = runs(line)
            if not as_json:
                for r in res:
                    print(f"{r['from'] + (ox if args[2] == 'row' else oy):5d} +{r['len']:<4d} {r['colour']}")
        elif cmd == "boxes":
            img = load(args[1])
            a, ox, oy = region(img, opt(args, "--region"))
            bg = background(a, opt(args, "--bg", "auto"))
            res = boxes(ink_mask(a, bg), int(opt(args, "--min", "1")))
            for b in res:
                b["x"] += ox
                b["y"] += oy
            if not as_json:
                print(f"background {hexc(bg)} · {len(res)} boxes")
                for b in res:
                    print(f"  x {b['x']:4d} y {b['y']:4d} w {b['w']:4d} h {b['h']:4d} ({b['pixels']} px)")
        elif cmd == "gaps":
            img = load(args[1])
            axis = args[2]
            a, ox, oy = region(img, opt(args, "--region"))
            bg = background(a, opt(args, "--bg", "auto"))
            sp = spans(ink_mask(a, bg), axis)
            off = ox if axis == "x" else oy
            n = a.shape[1] if axis == "x" else a.shape[0]
            res = {"background": hexc(bg), "spans": [[s + off, l] for s, l in sp],
                   "gaps": [sp[i + 1][0] - (sp[i][0] + sp[i][1]) for i in range(len(sp) - 1)],
                   "lead": sp[0][0] if sp else None, "trail": n - (sp[-1][0] + sp[-1][1]) if sp else None}
            if not as_json:
                print(f"background {res['background']} · lead {res['lead']} · trail {res['trail']}")
                print("spans " + " ".join(f"{s}+{l}" for s, l in res["spans"]))
                print("gaps  " + " ".join(str(g) for g in res["gaps"]))
        elif cmd == "centre":
            img = load(args[1])
            a, ox, oy = region(img, opt(args, "--region"))
            bg = background(a, opt(args, "--bg", "auto"))
            ys, xs = np.nonzero(ink_mask(a, bg))
            if not len(xs):
                print("px: no ink in the region", file=sys.stderr)
                return 1
            ink_cx = (xs.min() + xs.max() + 1) / 2.0
            ink_cy = (ys.min() + ys.max() + 1) / 2.0
            res = {"dx": round(ink_cx - a.shape[1] / 2.0, 2), "dy": round(ink_cy - a.shape[0] / 2.0, 2),
                   "ink": [int(xs.min()) + ox, int(ys.min()) + oy, int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)],
                   "left": int(xs.min()), "right": int(a.shape[1] - 1 - xs.max()),
                   "top": int(ys.min()), "bottom": int(a.shape[0] - 1 - ys.max())}
            if not as_json:
                print(f"dx {res['dx']} dy {res['dy']} · air left {res['left']} right {res['right']} top {res['top']} bottom {res['bottom']}")
        elif cmd == "hist":
            img = load(args[1])
            a, _, _ = region(img, opt(args, "--region"))
            cols, counts = np.unique(a.reshape(-1, 3), axis=0, return_counts=True)
            order = counts.argsort()[::-1][: int(opt(args, "--top", "12"))]
            res = [{"colour": hexc(cols[i]), "pixels": int(counts[i])} for i in order]
            if not as_json:
                for r in res:
                    print(f"{r['colour']} {r['pixels']}")
        elif cmd == "diff":
            a, b = load(args[1]), load(args[2])
            if a.shape != b.shape:
                print(f"px: sizes differ {a.shape[1]}x{a.shape[0]} vs {b.shape[1]}x{b.shape[0]}", file=sys.stderr)
                return 1
            tol = int(opt(args, "--tol", "0"))
            m = np.any(np.abs(a - b) > tol, axis=2)
            ys, xs = np.nonzero(m)
            res = {"differ": int(m.sum()),
                   "box": [int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)] if len(xs) else None}
            out = opt(args, "--out")
            if out:
                pic = np.where(m[..., None], np.array([255, 0, 0]), a // 3).astype(np.uint8)
                Image.fromarray(pic).save(out)
            if not as_json:
                print(f"{res['differ']} pixels differ" + (f" · in {res['box']}" if res["box"] else ""))
        elif cmd == "zoom":
            img = load(args[1])
            a, _, _ = region(img, args[2])
            s = int(args[3])
            Image.fromarray(np.kron(a, np.ones((s, s, 1))).astype(np.uint8)).save(args[4])
            res = {"out": args[4]}
        else:
            print(f"px: no command {cmd} (px.py --help)", file=sys.stderr)
            return 2
    except (IndexError, ValueError) as e:
        print(f"px: {cmd}: {e} (px.py --help)", file=sys.stderr)
        return 2
    if as_json:
        print(json.dumps(res))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
