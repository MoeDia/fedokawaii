#!/usr/bin/env python3
"""tools/picker-pack.py — the owner's picker page (r28 f16b), its pictures: each option of the sheets alone, 1:1, on a crop
of the real wallpaper. tools/picker-pack.sh makes the shots and calls this. No design here: the mock-ups are the sheets'.

    python3 tools/picker-pack.py wall SRC OUT           # the picture cropped to cover the screen, as swaybg shows it
    python3 tools/picker-pack.py lock WORK HI           # e-*
    python3 tools/picker-pack.py bar WORK FONTDIR HI    # f-*
    python3 tools/picker-pack.py power WORK HI          # g-*
    python3 tools/picker-pack.py window WORK SHOT HI/NAME MOOD   # the window in SHOT, what differs from the wall, with air
    python3 tools/picker-pack.py helium RUN WORK HI     # i-*
    python3 tools/picker-pack.py motion REC HI SET N MS CROP  # SET-N-dark.mp4 and .png from a recording of a whole screen
"""
import importlib.util
import pathlib
import sys

from PIL import Image, ImageChops

ROOT = pathlib.Path(__file__).resolve().parent
sys.dont_write_bytecode = True
MOODS = ("dark", "light")
AIR = 56


def tool(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), ROOT / f"{name}.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def wall(work, mood):
    return Image.open(pathlib.Path(work) / f"wall-{mood}.png").convert("RGB")


def key(im, ground, under):
    """im with every pixel of the colour ground replaced by under's."""
    mask = ImageChops.difference(im, Image.new("RGB", im.size, ground)).convert("L").point(lambda v: 255 if v else 0)
    return Image.composite(im, under, mask)


def cut_wall(src, out):
    im = Image.open(src).convert("RGB")
    s = max(1920 / im.width, 1080 / im.height)
    w, h = round(im.width * s), round(im.height * s)
    x, y = (w - 1920) // 2, (h - 1080) // 2
    im.resize((w, h), Image.LANCZOS).crop((x, y, x + 1920, y + 1080)).save(out)


def lock(work, hi):
    work, share = pathlib.Path(work), ROOT.parent / "configs/home/.local/share/fedokawaii"
    for m in MOODS:
        files = {0: share / m / "lock-scene.png"} | {n: work / "lock" / f"{m}-{n}.png" for n in (1, 2, 3)}
        for n, f in files.items():
            save_jpeg(Image.open(f).convert("RGB"), pathlib.Path(hi) / f"e-{n}-{m}.jpg")


def save_jpeg(im, out):
    for q in range(95, 79, -1):                     # (3 MB each at most)
        im.save(out, quality=q, subsampling=0, optimize=True)
        if out.stat().st_size <= 3_000_000:
            break
    print(out.name, im.size, "q", q, out.stat().st_size)


def save_png(im, out):
    im.save(out, optimize=True)
    print(pathlib.Path(out).name, im.size, pathlib.Path(out).stat().st_size)
    if pathlib.Path(out).stat().st_size > 3_000_000:
        sys.exit(f"{out}: over 3 MB")


def bar(work, fontdir, hi):
    from PIL import ImageFont
    B = tool("bar-options")
    fd = pathlib.Path(fontdir)
    fonts = (ImageFont.truetype(str(fd / "JF-Dot-Shinonome16.ttf"), 16),
             ImageFont.truetype(str(fd / "JF-Dot-Shinonome16B.ttf"), 16),
             ImageFont.truetype(str(fd / "JF-Dot-Shinonome14.ttf"), 14))
    H = 120
    for m in MOODS:
        w = wall(work, m)
        today = w.crop((0, 0, 1920, H))             # (the kit's bar shot: its own rows, the real wall behind)
        today.paste(Image.open(pathlib.Path(work) / m / "bar.png").convert("RGB"), (0, 0))
        save_png(today, f"{hi}/f-0-{m}.png")
        for n, o in enumerate(B.OPTIONS, 1):
            b = B.draw(m, o, fonts)
            strip = w.crop((0, 0, 1920, H))
            strip.paste(key(b.im, B.rgb(b.p["ground"]), w.crop((0, 0, 1920, b.im.height))), (0, 0))
            save_png(strip, f"{hi}/f-{n}-{m}.png")


def power(work, hi):
    P = tool("power-options")
    work = pathlib.Path(work)
    W, H = P.CELL
    x0, y0 = 960 - W, 540 - H // 2                  # rest and second press side by side, the wall running on under both
    for m in MOODS:
        rest, armed = (Image.open(work / m / f"power-{s}.png").convert("RGB") for s in ("rest", "armed"))
        # (the dim as the real dialog's: the shot's own ratio to the wall, read in a corner)
        w = wall(work, m)
        sample = (200, 200, 400, 300)
        a, b = rest.crop(sample).resize((1, 1), Image.BOX).getpixel((0, 0)), w.crop(sample).resize((1, 1), Image.BOX).getpixel((0, 0))
        dim = sum(a) / max(1, sum(b))
        print(m, "dim", round(dim, 3))
        under = w.crop((x0, y0, x0 + 2 * W, y0 + H)).point(lambda v, k=dim: round(v * k))
        today = under.copy()
        for i, shot in enumerate((rest, armed)):
            d = shot.crop((739, 443, 1181, 638))
            today.paste(d, (i * W + (W - d.width) // 2, (H - d.height) // 2))
        save_png(today, f"{hi}/g-0-{m}.png")
        for n, (_, fn, _) in enumerate(P.OPTIONS, 1):
            im = under.copy()
            for i, (on, asked) in enumerate(((0, None), (4, 4))):
                g = P.Canvas(m)
                fn(g, on, asked)
                im.paste(key(g.im, P.rgb(P.BACK[m]), under.crop((i * W, 0, i * W + W, H))), (i * W, 0))
            save_png(im, f"{hi}/g-{n}-{m}.png")


def window(work, shot, out, mood):
    im = Image.open(shot).convert("RGB")
    w = wall(work, mood)
    diff = ImageChops.difference(im, w).convert("L").point(lambda v: 255 if v > 2 else 0)
    x0, y0, x1, y1 = diff.crop((0, 40, 1920, 1080)).getbbox()
    y0, y1 = y0 + 40, y1 + 40
    print(pathlib.Path(out).name, "window", x1 - x0, "x", y1 - y0)
    save_png(im.crop((max(0, x0 - AIR), max(40, y0 - AIR), min(1920, x1 + AIR), min(1080, y1 + AIR))), out)


def helium(run, work, hi):
    run = pathlib.Path(run)
    names = ("now", "tsuitate", "mokuroku", "noren")
    for m in MOODS:
        w = wall(work, m)
        for n, name in enumerate(names):
            s = Image.open(run / m / f"{name}.png").convert("RGB")
            im = w.crop((480 - 40, 240 - 40, 480 + s.width + 40, 240 + s.height + 40))
            im.paste(s, (40, 40))
            save_png(im, f"{hi}/i-{n}-{m}.png")


def motion(rec, hi, st, n, ms, crop):
    """The events' frames found, the motion's first to its last with 0.3 s either side, at 60 fps, 1:1, under 3 MB. CROP
    W:H:X:Y, or auto: what moved on a whole screen's recording, with air (at most 1280 x 720). The still: the first event at half of MS."""
    import subprocess

    import numpy as np
    size = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "stream=width,height", "-of", "csv=p=0", rec],
                          capture_output=True, text=True, check=True).stdout.strip().split(",")
    w, h = int(size[0]), int(size[1])
    top = 34 if h == 1080 else 0                    # (a whole screen: under the bar, its clock would jump where the loop closes)
    h -= top
    raw = subprocess.Popen(["ffmpeg", "-v", "error", "-i", rec, "-vf", f"crop={w}:{h}:0:{top},fps=60,format=gray", "-f", "rawvideo", "-"],
                           stdout=subprocess.PIPE)
    prev, changed, box, i = None, [], None, 0
    while buf := raw.stdout.read(w * h):
        f = np.frombuffer(buf, np.uint8).reshape(h, w)
        if prev is not None:
            ys, xs = np.nonzero(np.abs(f.astype(np.int16) - prev) > 4)
            if len(ys) > 400:                       # (more than a blinking cursor)
                changed.append(i)
                b = (xs.min(), ys.min(), xs.max(), ys.max())
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        prev, i = f.astype(np.int16), i + 1
    raw.wait()
    if not changed:
        sys.exit(f"{rec}: nothing moved")
    if crop == "auto":
        print("moved", box)
        cw = min(1280, (box[2] - box[0] + 81) // 2 * 2)
        ch = min(720, (box[3] - box[1] + 81) // 2 * 2)
        cx = min(1920 - cw, max(0, (box[0] + box[2] - cw) // 2)) // 2 * 2
        cy = min(1080 - ch, max(top, (box[1] + box[3]) // 2 + top - ch // 2)) // 2 * 2
        crop = f"{cw}:{ch}:{cx}:{cy}"
    a, b = max(0, changed[0] - 18), changed[-1] + 19
    secs = (b - a) / 60
    print(f"{st}-{n}: frames {i}, moving {changed[0]}..{changed[-1]} ({len(changed)}), {secs:.2f} s, crop {crop}")
    if not 3 <= secs <= 5:
        print(f"{st}-{n}: NOT 3 to 5 s", file=sys.stderr)
    vf = f"crop={crop},fps=60,tpad=stop_mode=clone:stop_duration=1,trim=start_frame={a}:end_frame={b},setpts=PTS-STARTPTS,scale=in_range=pc:out_range=tv,format=yuv420p"
    out = pathlib.Path(hi) / f"{st}-{n}-dark.mp4"
    for crf in range(14, 34, 2):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", rec, "-vf", vf, "-an", "-c:v", "libx264", "-preset", "slow", "-crf", str(crf),
                        "-color_range", "tv", "-r", "60", "-movflags", "+faststart", str(out)], check=True)
        if out.stat().st_size <= 3_000_000:
            break
    print(out.name, "crf", crf, out.stat().st_size)
    key = changed[0] + round(int(ms) / 2 * 60 / 1000)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", rec, "-vf", f"crop={crop},fps=60,select=eq(n\\,{key})", "-frames:v", "1", "-update", "1",
                    str(out.with_suffix(".png"))], check=True)


if __name__ == "__main__":
    fn = {"motion": motion, "wall": cut_wall, "lock": lock, "bar": bar, "power": power, "window": window, "helium": helium}[sys.argv[1]]
    fn(*sys.argv[2:])
