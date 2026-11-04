#!/usr/bin/env python3
"""tools/art-pack.py — the art of art direction §1, §4 and §8 as pages of a design review: both moods,
real renders, each piece as the screen shows it and its pixels four times larger (tools/design-review.sh's
pack takes them: NN-short-name.png, a .md beside it, questions.md).

    python3 tools/art-pack.py DIR         # (.claude/review/next: packs stay out of git)

Reads what is committed — art/masters/out, the lock's files, the heads — and draws nothing itself.
Needs Pillow and numpy.
"""
import importlib.util
import pathlib
import sys
import tomllib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHARE = ROOT / "configs/home/.local/share/fedokawaii"
SCENE = (640, 360)
_spec = importlib.util.spec_from_file_location("build_heads", ROOT / "tools/build-heads.py")
bh = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bh)


def big(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def page(d, name, im, words):
    im.convert("RGB").save(d / f"{name}.png", optimize=True)
    (d / f"{name}.md").write_text(words + "\n", encoding="utf-8")


def scene_words(mood):
    kv = {}
    for line in (SHARE / mood / "lock-scene.txt").read_text(encoding="utf-8").splitlines():
        w = line.split("#")[0].split()
        if w:
            kv.setdefault(w[0], []).append(w[1:])
    return kv


def lock(d, mood, n, what):
    """the scene as the screen shows it, shut and open, with its flames and six marks; its gate's frames"""
    kv = scene_words(mood)
    x0, y0, w, h, frames = map(int, kv["gate"][0])
    strip = Image.open(SHARE / mood / "lock-gate.png").convert("RGB")
    scene = Image.open(SHARE / mood / "lock-scene.png").convert("RGB")
    fw, fh, _ = map(int, kv["frames"][0])
    flame = Image.open(SHARE / mood / "lock-flame.png").convert("RGBA").crop((0, 0, fw, fh))
    shut, opened = scene.copy(), scene.copy()
    shut.paste(strip.crop((0, 0, w, h)), (x0, y0))
    for im in (shut, opened):
        for fx, fy in (map(int, f) for f in kv["flame"]):
            im.paste(flame, (fx, fy), flame)
    rx, ry, pitch, _ = map(int, kv["row"][0])
    ink = [bh.rgb(c) for c in kv["mark"][0]]
    px = opened.load()
    for i in range(6):
        x = rx + pitch * i
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            px[x + dx, ry + dy] = ink[2]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            px[x + dx, ry + dy] = ink[0]
        px[x, ry] = ink[1]
    page(d, f"{n}-lock-{mood}-shut", big(shut, 3), f"The lock, {mood}, at rest: {what[0]} As your screen shows it.")
    page(d, f"{n + 1}-lock-{mood}-open", big(opened, 3), f"The lock, {mood}, after the secret key, six characters typed: {what[1]}")
    rows = Image.new("RGB", (3 * w * 3 + 24, 2 * h * 3 + 16), (60, 60, 60))
    for i in range(frames):
        rows.paste(big(strip.crop((i * w, 0, (i + 1) * w, h)), 3), (4 + (i % 3) * (w * 3 + 8), 4 + (i // 3) * (h * 3 + 8)))
    page(d, f"{n + 2}-lock-{mood}-gate", rows, f"The gate's {frames} frames, shut to open. The lock's motion is still to be wired: judge the drawing here, the timing later.")
    page(d, f"{n + 3}-lock-{mood}-detail-4x", big(scene.crop((8, 168, 200, 316)) if mood == "dark" else scene.crop((0, 120, 216, 268)), 4),
         "Four times larger: " + what[2])


def walls(d, n):
    spec = tomllib.loads((ROOT / "art/masters/masters.toml").read_text(encoding="utf-8"))
    for mood, what in (("dark", "demons and ghosts: sepia and vermilion"), ("light", "Kannon and tennin: ink, shu and gold on paper")):
        names = [k for k in spec if spec[k]["theme"] == mood]
        rows = (len(names) + 2) // 3
        sheet = Image.new("RGB", (3 * 648 + 8, rows * 368 + 8), (50, 50, 50))
        for i, k in enumerate(names):
            sheet.paste(Image.open(ROOT / f"art/masters/out/{k}.png").convert("RGB"), (8 + (i % 3) * 648, 8 + (i // 3) * 368))
        page(d, f"{n}-wallpapers-{mood}", sheet, f"The old masters, {what}. No cartouche, seal or poem card left, no seam, a calm band at the top for the bar, no face cut by an edge.")
        n += 1
        for k in names:
            im = Image.open(ROOT / f"art/masters/out/{k}.png").convert("RGB")
            page(d, f"{n}-wall-{k}", big(im, 3), f"{k}, as your screen shows it.")
            page(d, f"{n + 1}-wall-{k}-4x", big(im.crop((200, 112, 440, 247)), 4), f"{k}: its middle, four times larger.")
            n += 2
    return n


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    d = pathlib.Path(sys.argv[1])
    d.mkdir(parents=True, exist_ok=True)
    bh.looks(d)
    for kind, n, words in (("oni", "10", "The oni, one character at every size: the prompt, the bar's tile, 32, 56, fetch, the lock. Above as the screen shows them, below four times larger; shut and open at each. Few inks: the seal's red in its values, sumi, bone."),
                           ("kannon", "11", "The Kannon, the same way: her eyes closed and half open. Sumi, gofun, a gold ring, red only in the urna and the lips.")):
        (d / f"heads-{kind}.png").rename(d / f"{n}-heads-{kind}.png")
        (d / f"{n}-heads-{kind}.md").write_text(words + "\n", encoding="utf-8")
    lock(d, "dark", 20, ("the demon faces you, teeth locked, on a castle wall lit in three steps by two torches; a battle of oni and tennin carved either side.",
                         "his mouth is the gate, the password glows in it.",
                         "a carved panel, flat tones, the bevels turned to the torch."))
    lock(d, "light", 30, ("the same battle in the sky of an old screen, between bands of gold mist; the Kannon, eyes closed, a lotus bud in her hands.",
                          "the flower has opened, her eyes half open, the password lies in its heart. Her quote says: not saying is the flower.",
                          "the mist (suyari-gasumi: straight bars with rounded ends, an inner line, cut gold) and the fighters."))
    walls(d, 40)


if __name__ == "__main__":
    main()
