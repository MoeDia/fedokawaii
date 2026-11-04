#!/usr/bin/env python3
"""tools/art-pack.py — the wallpapers (art direction §4) as pages of a design review: each mood's sheet, then each
picture as the screen shows it (tools/design-review.sh's pack takes them: NN-short-name.png, a .md beside it, questions.md).

    python3 tools/art-pack.py DIR         # (.claude/review/next: packs stay out of git)

Reads what is committed, art/masters/out, and draws nothing itself.
Needs Pillow and numpy.
"""
import pathlib
import sys
import tomllib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent


QUESTIONS = """The wallpapers, cleaned: no text or seals, no seams, a calm band for the floating bar, the light set in ink, shu and gold.
1. You loved the light set: anything you loved in the dark set got lost? The Willow Kannon replaces the Goddess on a Dragon.
2. More demons, more angels, or is this the set?
"""


def big(im, k):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def page(d, name, im, words):
    im.convert("RGB").save(d / f"{name}.png", optimize=True)
    (d / f"{name}.md").write_text(words + "\n", encoding="utf-8")


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
            page(d, f"{n}-wall-{k}", big(im, 3), f"{k}, as your screen shows it.")     # (no 4× page: the owner, 19:06: a duplicate)
            n += 1
    return n


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    d = pathlib.Path(sys.argv[1])
    d.mkdir(parents=True, exist_ok=True)
    walls(d, 40)
    (d / "questions.md").write_text(QUESTIONS, encoding="utf-8")


if __name__ == "__main__":
    main()
