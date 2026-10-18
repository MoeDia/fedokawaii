#!/usr/bin/env python3
"""apps.sh's screen helper (grim + PIL), next to shoot.sh's imgtool.py.

  appshot.py window FULL.png CROP.png X,Y WxH [--settle S] [--timeout S] [--min S]
        grab the screen until the window's rectangle has held still for --settle seconds
        (other parts of the screen, the bar's clock and meters, may change), then save that
        one frame whole (FULL) and the rectangle 1:1 (CROP). Exit 0 even on a timeout (the
        last frame is kept and "TIMEOUT" goes to stderr); print the rectangle.
  appshot.py palette PNG HEX…
        print, for each colour, the share of the picture's pixels that have it exactly
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


def opts(args, **defaults):
    out, rest, i = dict(defaults), [], 0
    while i < len(args):
        if args[i].startswith("--"):
            k = args[i][2:].replace("-", "_")
            out[k] = type(defaults[k])(args[i + 1])
            i += 2
        else:
            rest.append(args[i])
            i += 1
    return rest, out


def window(args):
    rest, o = opts(args, settle=1.0, timeout=20.0, min=0.0)
    full, crop, pos, size = rest
    x, y = map(int, pos.split(","))
    w, h = map(int, size.split("x"))
    box = (x, y, x + w, y + h)
    t0 = time.monotonic()
    last, since = None, None
    while True:
        cur = grab()
        now = time.monotonic()
        part = cur.crop(box)
        if last is not None and ImageChops.difference(last, part).getbbox() is None:
            since = since or now
            if now - since >= o["settle"] and now - t0 >= o["min"]:
                break
        else:
            since = None
        last = part
        if now - t0 > o["timeout"]:
            print("TIMEOUT the window kept changing; keeping the last frame", file=sys.stderr)
            break
        time.sleep(0.1)
    cur.save(full)
    part.save(crop)
    print(x, y, w, h)


def palette(args):
    im = Image.open(args[0]).convert("RGB")
    n = im.width * im.height
    counts = {}
    for c, rgb in im.getcolors(n) or []:
        counts[rgb] = c
    for hx in args[1:]:
        h = hx.lstrip("#")
        rgb = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        print(f"#{h} {100.0 * counts.get(rgb, 0) / n:.2f}%")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "window":
        window(sys.argv[2:])
    elif cmd == "palette":
        palette(sys.argv[2:])
    else:
        sys.exit(__doc__)
