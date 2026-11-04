#!/usr/bin/env bash
# tools/regress/learn-cover.sh — never again (the owner, 4 Nov 18:49): the Learn book's cover where he asked for it, to
# the pixel, in both moods. A headless kit (the real GPU, nothing of the session). Super+U → learning → lessons: the whole
# picture (its full width, no side clipped), its left edge on the words' column and its top level with the list's first row,
# leaving the pane when the cursor does and back when it returns. Super+R: the book on the shelf, its cover in the pane.
#   bash tools/regress/learn-cover.sh [KIT OPTION…]   (e.g. --bin bin --repo-art --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (what, said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$(mktemp -d /dev/shm/regress-cover.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT   # (KEEP=1: the shots kept, the folder said)
# the menu of this tree: its toolkit (the cover, the book) is the repository, whichever bin the kit runs
mkdir -p "$out/bin"
sed "s|^TK=/usr/local/lib/fedokawaii\$|TK=$repo|" "$repo/system/fedokawaii" >"$out/bin/fedokawaii"; chmod +x "$out/bin/fedokawaii"
cat >"$out/play.sh" <<PLAY
mkdir -p "\$HOME/.local/state/fedokawaii" "\$HOME/Books"
printf 'how-to-read\t2026-11-01\n' >"\$HOME/.local/state/fedokawaii/learn"
footclient -a float -T system -W 100x22 -- env KAWA_LEARN=$repo/docs/learn $out/bin/fedokawaii --popup >/dev/null 2>&1 &
nap 2.5
key Left; nap 1.5
shot pane
key Down; nap 0.8
shot away
key Up; nap 0.8
shot back
key Escape; nap 0.6
footclient -a float -T books -W 104x29 -- env KAWA_LEARN_BOOK=$repo/docs/Fedokawaii-Learn.pdf kawa-books --tui >/dev/null 2>&1 &
nap 3.5
shot books
key Escape; nap 0.4
PLAY
for th in dark light; do
  mkdir -p "$out/$th"
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "learn-cover: the kit failed ($th): $(tail -n 1 "$out/kit-$th.log")" >&2; exit 2; }
done
python3 -I - "$out" "$repo" <<'PY'
import re, sys
from PIL import Image, ImageChops, ImageStat
out, repo = sys.argv[1:3]
bad, said = [], []
cover = Image.open(f"{repo}/docs/learn/cover-thumb.png").convert("RGB")
def box(im):
    """the picture in a shot, or None: the columns with a long run off the ground in many colours (a frame or a rule is one
    colour, words are short runs), and how far the middle one's run goes"""
    W, H = im.size; px = im.load(); g = px[5, H - 5]
    def run(x):                        # the longest run off the ground in column x, gaps of 3 px forgiven (dark ink near the ground)
        best = (0, 0); start = None; gap = 0
        for y in range(36, H - 8):
            if px[x, y] != g:
                if start is None: start = y
                gap = 0
                if y - start > best[1] - best[0]: best = (start, y + 1)
            elif start is not None:
                gap += 1
                if gap > 3: start = None
        return best
    def rich(x):
        y0, y1 = run(x)
        return y1 - y0 >= 150 and len({px[x, y] for y in range(y0, y1)}) > 12
    cols = [x for x in range(W // 2, W) if rich(x)]
    if not cols: return None
    y0, y1 = run((cols[0] + cols[-1]) // 2)
    return cols[0], y0, cols[-1] + 1, y1
def alike(im, b, name, th):
    a = im.crop(b).convert("RGB")
    h = round(a.width * 475 / 336)     # (Super+R's box trims a few per cent off the top and the foot)
    e = cover.resize((a.width, h), Image.LANCZOS).crop((0, (h - a.height) // 2, a.width, (h - a.height) // 2 + a.height))
    q = (a.width // 4, a.height // 4)  # (the sixel's dither is no difference: compared at a quarter)
    d = ImageStat.Stat(ImageChops.difference(a.resize(q, Image.BOX), e.resize(q, Image.BOX))).mean
    if sum(d) / 3 > 18: bad.append(f"{th}: {name}: not the cover (mean difference {sum(d) / 3:.0f})")
for th in ("dark", "light"):
    im = Image.open(f"{out}/{th}/pane.png").convert("RGB"); px = im.load(); W, H = im.size
    b = box(im)
    if not b: bad.append(f"{th}: no cover in the pane"); continue
    w, h = b[2] - b[0], b[3] - b[1]
    if abs(w / h - 336 / 475) > .01: bad.append(f"{th}: the pane's cover is {w}x{h}: clipped or stretched")
    alike(im, b, "the pane", th)
    t = next(j for j in range(40, H) if px[W // 2, j] != px[5, H - 5])                 # the window's top
    sel = re.search(r"^select=#?([0-9a-f]{6})", open(f"{repo}/configs/home/.config/fedokawaii/themes/{th}/panel.conf").read(), re.M)[1]
    rgb = tuple(int(sel[i:i + 2], 16) for i in (0, 2, 4))
    row = next((j for j in range(t, H) if any(px[x, j] == rgb for x in range(W // 3, W // 2))), None)
    if row != b[1]: bad.append(f"{th}: the cover's top {b[1]}, the list's first row {row}")
    if box(Image.open(f"{out}/{th}/away.png").convert("RGB")): bad.append(f"{th}: the cover stays when the cursor leaves")
    back = Image.open(f"{out}/{th}/back.png").convert("RGB")
    if ImageStat.Stat(ImageChops.difference(back.crop(b), im.crop(b))).sum != [0, 0, 0]: bad.append(f"{th}: another picture when the cursor returns")
    bk = Image.open(f"{out}/{th}/books.png").convert("RGB")
    c = box(bk)
    if not c: bad.append(f"{th}: no cover in Super+R"); continue
    alike(bk, c, "Super+R", th)
    said.append(f"{th}: Super+U {w}x{h} at {b[0]},{b[1]}, Super+R {c[2] - c[0]}x{c[3] - c[1]}")
print("\n".join("learn-cover: " + x for x in bad) if bad else "learn-cover: held — " + ", ".join(said))
sys.exit(1 if bad else 0)
PY
rc=$?
[[ ${KEEP:-} == 1 ]] && echo "learn-cover: shots kept in $out"
exit "$rc"
