#!/usr/bin/env python3
"""tools/motion-exact.py — motion as it is designed, frame by frame (r28 m1), no recording: the play of tools/motion-exact.sh
steps a test build of dwl's animation clock 1/60 s a frame ($XDG_RUNTIME_DIR/dwl-stepclock) and grim takes each frame.
    freeze                       (inside the play) the clock stopped at now
    frames DIR COUNT             (inside the play) COUNT frames into DIR: a shot, then 1/60 s on
    make RUN OUT SET N MOOD OPEN CLOSE [SEQS]
                                 from RUN/NN-open, NN-close …: SET-N-MOOD.mp4, -slow.mp4 (each frame 4 times), -strip.png (every
                                 frame of the first opening, its ms), .png (the opening at half way) in OUT; prints "measured"
                                 and a line per event; SEQS keeps the small frames for pairs. Exit 1: a duration is over a frame off
    pairs SEQS [SET]             every pair's openings and closings compared. Exit 1: two nearly the same
"""
import itertools
import json
import os
import pathlib
import subprocess
import sys
import time

TOP = 34            # (the bar: its clock runs on its own)
FRAME = 1000 / 60
CURSOR = 200        # (fewer pixels changed: a terminal's blinking cursor, in real time, not the motion)
SAME = 0.12         # (pairs: below this, on a sequence's own scale, the eye cannot tell them apart; see pairs)


def clockfile():
    return pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / "dwl-stepclock"


def setclock(ms):
    tmp = clockfile().with_suffix(".tmp")
    tmp.write_text(f"{ms:.6f}\n")
    tmp.rename(clockfile())


def freeze():
    setclock(time.monotonic() * 1000)


def frames(folder, count):
    folder = pathlib.Path(folder)
    folder.mkdir(parents=True)
    t0 = float(clockfile().read_text())
    for k in range(int(count)):
        setclock(t0 + k * FRAME)
        subprocess.run(["grim", "-t", "ppm", str(folder / f"{k:04d}.ppm")], check=True)
    setclock(t0 + int(count) * FRAME)


def load(path):
    from PIL import Image
    return Image.open(path).convert("RGB")


def events(run):
    """[(name, kind, [frame files])] in their order; each event's frame 0 shows the clock at the event's start"""
    out = []
    for d in sorted(p for p in pathlib.Path(run).iterdir() if p.is_dir() and p.name[:2].isdigit()):
        out.append((d.name, d.name[3:], sorted(d.glob("*.ppm"))))
    return out


def measure(evs):
    """Per event: the last frame that differs from the one before it (under the bar, more than a cursor), its first, and the box of what moved"""
    import numpy as np
    res, box = [], None
    prev = None
    for name, kind, files in evs:
        changed = []
        for k, f in enumerate(files):
            cur = np.asarray(load(f))[TOP:]
            if prev is not None:
                ys, xs = np.nonzero((cur != prev).any(axis=2))
                if len(ys) > CURSOR:
                    changed.append(k)
                    b = (xs.min(), ys.min() + TOP, xs.max(), ys.max() + TOP)
                    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
            prev = cur
        res.append({"name": name, "kind": kind, "frames": len(files), "changed": changed})
    return res, box


def crop_of(box):
    if box is None:
        sys.exit("nothing moved")
    cw = min(1920, (box[2] - box[0] + 81) // 2 * 2)     # (everything that moved, however large: a window cut off looks still while its gate runs below the cut)
    ch = min(1080 - TOP, (box[3] - box[1] + 81) // 2 * 2)
    cx = min(1920 - cw, max(0, (box[0] + box[2] - cw) // 2)) // 2 * 2
    cy = min(1080 - ch, max(TOP, (box[1] + box[3] - ch) // 2)) // 2 * 2
    return cw, ch, cx, cy


def encode(listing, out, crop, slow):
    cw, ch, cx, cy = crop
    rate = 15 if slow else 60
    vf = f"crop={cw}:{ch}:{cx}:{cy},scale=in_range=pc:out_range=tv,format=yuv420p"
    for crf in range(14, 34, 2):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "image2", "-framerate", str(rate), "-i", str(listing / "%05d.ppm"), "-vf", vf, "-an",
                        "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-color_range", "tv", "-r", "60", "-movflags", "+faststart", str(out)], check=True)
        if out.stat().st_size <= 3_000_000:
            break


def strip(files, last, crop, out):
    from PIL import Image, ImageDraw, ImageFont
    cw, ch, cx, cy = crop
    tw = 320
    th = round(ch * tw / cw)
    cols, cap, gap = 6, 24, 4
    shown = files[:last + 2]
    rows = (len(shown) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + gap) + gap, rows * (th + cap + gap) + gap), (16, 14, 18))
    draw = ImageDraw.Draw(sheet)
    fontfile = subprocess.run(["fc-match", "-f", "%{file}", "Sumi Term"], capture_output=True, text=True, check=True).stdout
    font = ImageFont.truetype(fontfile, 16)
    for k, f in enumerate(shown):
        x, y = gap + (k % cols) * (tw + gap), gap + (k // cols) * (th + cap + gap)
        sheet.paste(load(f).crop((cx, cy, cx + cw, cy + ch)).resize((tw, th), Image.LANCZOS), (x, y + cap))
        draw.text((x + 2, y + 2), f"{round(k * FRAME)} ms", font=font, fill=(236, 228, 214))
    sheet.save(out, optimize=True)


def make(run, out, st, n, mood, opening, closing, seqs=None):
    import numpy as np
    from PIL import Image
    out = pathlib.Path(out)
    evs = events(run)
    res, box = measure(evs)
    crop = crop_of(box)
    design = {"open": int(opening), "close": int(closing)}
    bad, got = [], {}
    for e in res:
        if e["kind"] == "rest":
            continue
        last = e["changed"][-1] if e["changed"] else 0
        first = e["changed"][0] if e["changed"] else 0
        e["ms"] = round(last * FRAME)
        want = design[e["kind"]]
        off = abs(e["ms"] - want) > FRAME + 0.5
        print(f"{e['name']}: {len(e['changed'])} changed of {e['frames']}, frames {first}..{last}, {e['ms']} ms, designed {want}" + (" OFF" if off else ""))
        if off:
            bad.append(e["name"])
        got.setdefault(e["kind"], e["ms"])
    listing = pathlib.Path(run) / "seq"
    listing.mkdir(exist_ok=True)
    i = 0
    for _, _, files in evs:
        for f in files:
            (listing / f"{i:05d}.ppm").symlink_to(f.resolve())
            i += 1
    stem = f"{st}-{n}-{mood}"
    encode(listing, out / f"{stem}.mp4", crop, False)
    encode(listing, out / f"{stem}-slow.mp4", crop, True)
    op = next(j for j, e in enumerate(res) if e["kind"] == "open")
    strip(evs[op][2], res[op]["changed"][-1] if res[op]["changed"] else 0, crop, out / f"{stem}-strip.png")
    mid = evs[op][2][min(round(int(opening) / 2 / FRAME), len(evs[op][2]) - 1)]
    cw, ch, cx, cy = crop
    load(mid).crop((cx, cy, cx + cw, cy + ch)).save(out / f"{stem}.png", optimize=True)
    words = f"open {got.get('open', 0)} ms / close {got.get('close', 0)} ms"
    print(f"measured: {words}; crop {cw}x{ch}+{cx}+{cy}; {i} frames, {i / 60:.2f} s, slow {i / 15:.2f} s")
    print(f"{stem}: {(out / (stem + '.mp4')).stat().st_size} + {(out / (stem + '-slow.mp4')).stat().st_size} bytes")
    if seqs:
        seqs = pathlib.Path(seqs)
        seqs.mkdir(parents=True, exist_ok=True)
        keep = {}
        for e, (_, kind, files) in zip(res, evs, strict=True):
            if kind == "rest" or kind in keep or not e["changed"]:
                continue
            last = e["changed"][-1]
            keep[kind] = np.stack([np.asarray(load(f).convert("L").resize((240, 135), Image.BOX), np.uint8) for f in files[:last + 1]])
        np.savez_compressed(seqs / f"{stem}.npz", **keep)
        (seqs / f"{stem}.json").write_text(json.dumps({"measured": words, "open": got.get("open"), "close": got.get("close")}))
    if bad:
        print(f"{stem}: OFF the design by over a frame: {' '.join(bad)}", file=sys.stderr)
        sys.exit(1)


def pairs(seqs, st=None):
    """The same moments of two motions (each at 16 points of its own length) against how much a motion moves at all: 0 is the same picture
    at every moment. Durations are said beside it, because the same path at another speed is still another motion to the eye."""
    import numpy as np
    seqs = pathlib.Path(seqs)
    names = sorted(p.stem for p in seqs.glob("*.npz") if st is None or p.stem.startswith(st + "-"))
    near = 0
    loaded = {n: np.load(seqs / f"{n}.npz") for n in names}

    def at16(s):
        return s[np.round(np.linspace(0, len(s) - 1, 16)).astype(int)].astype(np.float32)
    for a, b in itertools.combinations(names, 2):
        if a.split("-")[2:] != b.split("-")[2:]:        # (one mood against the same mood)
            continue
        words = []
        same = True
        for kind in ("open", "close"):
            if kind not in loaded[a] or kind not in loaded[b]:
                continue
            x, y = loaded[a][kind], loaded[b][kind]
            xs, ys = at16(x), at16(y)
            scale = max(np.abs(xs - xs[0]).mean(), np.abs(ys - ys[0]).mean(), 1e-3)
            score = float(np.abs(xs - ys).mean() / scale)
            ratio = max(len(x), len(y)) / min(len(x), len(y))
            words.append(f"{kind} {score:.2f} ({len(x)} and {len(y)} frames)")
            same = same and score < SAME and ratio < 1.15
        near += same
        print(f"{a} {b}: {', '.join(words)}" + (" NEARLY THE SAME" if same else ""))
    if near:
        sys.exit(1)


if __name__ == "__main__":
    fn = {"freeze": freeze, "frames": frames, "make": make, "pairs": pairs}[sys.argv[1]]
    fn(*sys.argv[2:])
