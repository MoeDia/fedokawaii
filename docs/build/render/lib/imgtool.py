#!/usr/bin/env python3
"""shoot.sh's screen helper (grim + PIL). Every frame is grabbed losslessly (PPM) and
saved as PNG, so the files are exactly what the compositor showed.

  imgtool.py grab OUT.ppm                       one full-screen frame
  imgtool.py capture BASE.ppm FULL.png CROP.png [--mask-top N] [--timeout S] [--min S]
                     [--settle S] [--pad N]
        wait until the screen (below row N: the bar's clock and CPU meter keep changing)
        differs from BASE and then holds still for --settle seconds; save that frame as
        FULL.png and the changed area as CROP.png; print the area as "x y w h"
  imgtool.py wait-same BASE.ppm [--mask-top N] [--timeout S]
        wait until the screen below row N looks like BASE again (a notice has gone)
  imgtool.py bbox A.ppm B.ppm [--mask-top N]   print the changed area "x y w h"
  imgtool.py crop IN.png X Y W H OUT.png
"""
import io
import subprocess
import sys
import time

from PIL import Image, ImageChops


def grab():
    p = subprocess.run(["grim", "-t", "ppm", "-"], capture_output=True, timeout=10)
    if p.returncode != 0:
        raise RuntimeError("grim failed: " + p.stderr.decode(errors="replace"))
    return Image.open(io.BytesIO(p.stdout)).convert("RGB")


def masked(img, top):
    return img.crop((0, top, img.width, img.height)) if top else img


def bbox(a, b, top=0):
    d = ImageChops.difference(masked(a, top), masked(b, top)).getbbox()
    if not d:
        return None
    x0, y0, x1, y1 = d
    return x0, y0 + top, x1 - x0, y1 - y0


def opts(args, **defaults):
    out = dict(defaults)
    i = 0
    rest = []
    while i < len(args):
        a = args[i]
        if a.startswith("--"):
            key = a[2:].replace("-", "_")
            out[key] = type(defaults.get(key, ""))(args[i + 1])
            i += 2
        else:
            rest.append(a)
            i += 1
    return rest, out


def main():
    cmd, args = sys.argv[1], sys.argv[2:]
    if cmd == "grab":
        grab().save(args[0])
    elif cmd == "bbox":
        rest, o = opts(args, mask_top=0)
        b = bbox(Image.open(rest[0]).convert("RGB"), Image.open(rest[1]).convert("RGB"), o["mask_top"])
        print(*(b or ()))
    elif cmd == "crop":
        src, x, y, w, h, out = args
        x, y, w, h = map(int, (x, y, w, h))
        Image.open(src).crop((x, y, x + w, y + h)).save(out)
    elif cmd == "capture":
        rest, o = opts(args, mask_top=0, timeout=10.0, min=0.6, settle=0.45, pad=0)
        base = Image.open(rest[0]).convert("RGB")
        t0 = time.monotonic()
        last = None
        since = None
        while True:
            cur = grab()
            now = time.monotonic()
            changed = bbox(base, cur, o["mask_top"]) is not None
            if changed and last is not None and bbox(last, cur, o["mask_top"]) is None:
                since = since or now
                if now - since >= o["settle"] and now - t0 >= o["min"]:
                    break
            else:
                since = None
            last = cur
            if now - t0 > o["timeout"]:
                if not changed:
                    print("TIMEOUT nothing appeared", file=sys.stderr)
                    sys.exit(1)
                print("TIMEOUT still changing; keeping the last frame", file=sys.stderr)
                break
            time.sleep(0.1)
        cur.save(rest[1])
        b = bbox(base, cur, o["mask_top"])
        x, y, w, h = b
        p = o["pad"]
        x0, y0 = max(0, x - p), max(0, y - p)
        x1, y1 = min(cur.width, x + w + p), min(cur.height, y + h + p)
        cur.crop((x0, y0, x1, y1)).save(rest[2])
        print(x0, y0, x1 - x0, y1 - y0)
    elif cmd == "wait-same":
        rest, o = opts(args, mask_top=0, timeout=10.0)
        base = Image.open(rest[0]).convert("RGB")
        t0 = time.monotonic()
        while bbox(base, grab(), o["mask_top"]) is not None:
            if time.monotonic() - t0 > o["timeout"]:
                print("TIMEOUT screen did not return to its base", file=sys.stderr)
                sys.exit(1)
            time.sleep(0.15)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
