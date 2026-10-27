# T14 drafts: animated 12 × 12 icons (frames), previewed side by side at 8× and 1×
import sys
from PIL import Image, ImageDraw
F = {}
F["tv"] = ["""
..#......#..
...#....#...
....#..#....
.....##.....
############
#..........#
#.########.#
#.#......#.#
#.#......#.#
#.########.#
############
..#......#..
""", """
..#......#..
...#....#...
....#..#....
.....##.....
############
#..........#
#.########.#
#.#......#.#
#.#.####.#.#
#.########.#
############
..#......#..
""", """
..#......#..
...#....#...
....#..#....
.....##.....
############
#..........#
#.########.#
#.#.####.#.#
#.#......#.#
#.########.#
############
..#......#..
""", """
...#....#...
...#....#...
....#..#....
.....##.....
############
#..........#
#.########.#
#.#......#.#
#.#......#.#
#.########.#
############
..#......#..
"""]
def dl(k):
    # the arrow (a shaft and a head) dropping k rows into its tray
    rows = [["."] * 12 for _ in range(12)]
    top = -3 + k
    for y in range(top, top + 6):
        if 0 <= y < 8:
            rows[y][5] = rows[y][6] = "#"
    hy = top + 6
    for i, w in enumerate((5, 3, 1)):
        y = hy + i
        if 0 <= y < 9:
            for x in range(6 - w // 2 - 1 + (1 if w == 1 else 0) - (0), 6 + w // 2 + 1):
                pass
    for i, (a, b) in enumerate(((3, 8), (4, 7), (5, 6))):
        y = hy + i
        if 0 <= y < 10:
            for x in range(a, b + 1):
                rows[y][x] = "#"
    for x in range(12):
        rows[11][x] = "#"
    rows[9][0] = rows[10][0] = rows[9][11] = rows[10][11] = "#"
    return "\n".join("".join(r) for r in rows)
F["download"] = [dl(k) for k in range(6)]
F["rec"] = ["""
............
............
....####....
...######...
..########..
..########..
..########..
..########..
...######...
....####....
............
............
""", """
............
............
....####....
...#....#...
..#......#..
..#......#..
..#......#..
..#......#..
...#....#...
....####....
............
............
"""]
def grid(s):
    r = s.strip("\n").split("\n"); assert len(r) == 12 and all(len(x) == 12 for x in r), [len(x) for x in r]; return r
S = 8; cw = 12 * S + 16
n = sum(len(v) for v in F.values())
im = Image.new("RGB", (n * cw + 20, 12 * S + 60), (60, 60, 60)); d = ImageDraw.Draw(im)
k = 0
for name, frames in F.items():
    for i, fr in enumerate(frames):
        g = grid(fr); ox = 10 + k * cw
        d.rectangle([ox - 2, 8, ox + 12 * S + 1, 8 + 12 * S + 1], fill=(0x18, 0x17, 0x15))
        for y, row in enumerate(g):
            for x, c in enumerate(row):
                if c == "#":
                    d.rectangle([ox + x * S, 10 + y * S, ox + x * S + S - 1, 10 + y * S + S - 1], fill=(0xd4, 0xbf, 0x9a))
                    im.putpixel((ox + x, 12 * S + 20 + y), (0xd4, 0xbf, 0x9a))
        d.text((ox, 12 * S + 40), f"{name}-{i}", fill=(255, 255, 255)); k += 1
im.save(sys.argv[1]); print(im.size)
