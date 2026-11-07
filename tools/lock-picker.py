#!/usr/bin/env python3
"""tools/lock-picker.py — lock-picker.sh's two small jobs.
    still DIR OUT   the frame with most of the samurai on screen (a cut in full swing), before the unlock's dissolve
    picker HI       HI/picker.json: the sets L and L2 after the pixel sets; e and e2, which they replace, gone with their files"""
import json
import pathlib
import sys

import numpy as np
from PIL import Image

SETS = (("L", "dark", "The lock, dark: his walls", ("shiro", "a castle at night"), ("kozan", "a mine"), ("suichu", "a sunken temple"), ("kaji", "a sword forge")),
        ("L2", "light", "The lock, light: her walls", ("haru", "a spring town"), ("kumo", "pavilions in the clouds"), ("yu", "a hot-spring mountain"), ("yuki", "a snow shrine")))
POINTER = (98, 100, 16, 23)      # the test's still pointer, painted out: the proof reports its box
NOTE = "The real lock, headless, with a stand-in password: idle, the first key, a cut per key, delete, a wrong try, the right one, the unlock. 1920 by 1080, the png its fullest frame. The marks' place is not final."


def still(work, out):
    work = pathlib.Path(work)
    files = sorted((work / "frames").glob("*.png"))
    files = files[:len(files) * 7 // 10]
    base = np.asarray(Image.open(work / "art/lock-scene.png").convert("RGB"))[254:318, 284:356]
    def fullness(f):
        cell = np.asarray(Image.open(f).convert("RGB"))[254 * 3:318 * 3:3, 284 * 3:356 * 3:3]
        return (cell != base).any(axis=2).sum()
    Image.open(max(files, key=fullness)).convert("RGB").save(out)
    x, y, w, h = POINTER
    picture = Image.open(out)
    picture.paste(Image.open(work / "art/lock-scene.png").convert("RGB").resize((1920, 1080), Image.NEAREST).crop((x, y, x + w, y + h)), (x, y))
    picture.save(out, optimize=True)


def picker(hi):
    hi = pathlib.Path(hi)
    path = hi / "picker.json"
    entries = json.loads(path.read_text())
    for e in entries:
        if e["set"] in ("e", "e2"):
            for o in e["options"]:
                for f in o["files"]:
                    (hi / f).unlink(missing_ok=True)
    entries = [e for e in entries if e["set"] not in ("e", "e2", "L", "L2")]
    new = [{"set": st, "title": title, "kind": "motion", "provisional": 1, "moods": [mood],
            "options": [{"n": n, "name": name, "text": text, "files": [f"{st}-{n}-{mood}.mp4", f"{st}-{n}-{mood}.png"]}
                        for n, (name, text) in enumerate(walls, 1)], "note": NOTE} for st, mood, title, *walls in SETS]
    at = next(i for i, e in enumerate(entries) if e["set"] == "PA") + 1
    entries[at:at] = new
    path.write_text(json.dumps(entries, ensure_ascii=False, indent=1) + "\n")


if __name__ == "__main__":
    {"still": still, "picker": picker}[sys.argv[1]](*sys.argv[2:])
