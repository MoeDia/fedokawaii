#!/usr/bin/env bash
# tools/regress/float-exit.sh — never again (lane-review, 4 Nov: a floating terminal rolled up as an empty page: on Esc fzf wiped
# its screen, foot drew it, the window closed, and dwl rolled up the blank): each window that ends with its program — Super+R,
# Super+W, the git screen, the file dialog (yazi) — opened in a headless dwl (tools/kit.sh, the real GPU, both themes), closed
# by Esc and by its other way out, recorded, and every frame from the key to the end looked at: while the shrinking window still
# shows its first text row, that row is there, its ink the open page's. A recording's frames, for looking only (wf-recorder; timing is
# the frame log's: tools/anim-check.sh).
#   bash tools/regress/float-exit.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$(mktemp -d /dev/shm/regress-float.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
sed "s|@REPO@|$repo|" >"$out/play.sh" <<'PLAY'
REPO=@REPO@
export PATH="$KIT_OUT/stub:$PATH"
mkdir -p "$KIT_OUT/stub" "$HOME/books" "$HOME/dojo/demo"
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/zathura"; chmod +x "$KIT_OUT/stub/zathura"
rm -rf "$HOME/.config/yazi"; cp -a "$REPO/configs/home/.config/yazi" "$HOME/.config/yazi"
cp "$REPO/configs/home/.config/fedokawaii/screen.sh" "$HOME/.config/fedokawaii/screen.sh"
for b in One Two Three; do magick -size 595x842 xc:white "$HOME/books/$b.pdf"; done
git -C "$HOME/dojo/demo" init -q 2>/dev/null
panel; nap 0.5
rec() { wf-recorder -y -c ffv1 -f "$KIT_OUT/$1.mkv" >/dev/null 2>&1 & R=$!; nap 0.8; }
end() { nap 1.1; kill -INT "$R"; wait "$R" 2>/dev/null; nap 0.3; }
# the books: Esc · Enter (a book opened: the stand-in, the window ends)
chord logo r; nap 3; rec books-esc; key Escape; end
chord logo r; nap 3; rec books-enter; key Return; end
# the wallpapers: Esc · Enter on the one shown: nothing set, the window ends
chord logo w; nap 3; rec wall-esc; key Escape; end
chord logo w; nap 3; rec wall-enter; key Return; end
# the git screen, floating as a menu for the look of it: Esc
setsid -f kawa-term --float --once git git 100x29 -- kawa-git; nap 2; rec git-esc; key Escape; end
# the file dialog (yazi): Esc · q
setsid -f kawa-file --choose >/dev/null 2>&1; nap 2.5; rec dialog-esc; key Escape; end
PLAY
fail=0
no() { echo "float-exit ($th): $*" >&2; fail=1; }
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" --time 180 "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "float-exit: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  for s in books-esc books-enter wall-esc wall-enter git-esc dialog-esc; do
    v=$out/$th/$s.mkv
    [[ -s $v ]] || { no "$s: nothing recorded"; continue; }
    d=$out/$th/$s; mkdir -p "$d"
    ffmpeg -nostdin -loglevel error -i "$v" -fps_mode passthrough "$d/%04d.png" || { no "$s: the recording does not decode"; continue; }
    r=$(python3 -I - "$d" <<'EOF'
import os, sys
import numpy as np
from PIL import Image
d = sys.argv[1]
names = sorted(os.listdir(d))
first = np.asarray(Image.open(os.path.join(d, names[0])).convert("RGB"), dtype=np.int16)
H, W, _ = first.shape
g = first[H - 5, 5]
far = lambda a: np.abs(a - g).sum(axis=2) > 60
open_ = far(first)
open_[:30] = False
# (the window's box: the columns and rows with a long run of ink — the pointer is in the recording too, and small)
cols, rows_ = np.nonzero(open_.sum(axis=0) > 60)[0], np.nonzero(open_.sum(axis=1) > 60)[0]
if not len(cols) or not len(rows_):
    print("none"); sys.exit()
x0, x1, y0, y1 = cols.min(), cols.max(), rows_.min(), rows_.max()
# the first text row: under the top hairline, the first band of rows with ink but for the frame's two sides
inner = open_[y0 + 2:y1 - 2, x0 + 4:x1 - 4]
rows = np.nonzero(inner.sum(axis=1) > 3)[0] + y0 + 2
ya = rows[0]
yb = ya
while yb + 1 in set(rows.tolist()) and yb - ya < 22:
    yb += 1
yb += 1
head = open_[ya:yb, x0 + 4:x1 - 4]
was = head.sum()
if was < 20:
    print("none"); sys.exit()
blank, seen = 0, 0
for n in names[1:]:
    b = far(np.asarray(Image.open(os.path.join(d, n)).convert("RGB"), dtype=np.int16))
    if (b[y0:y1 + 1, x0:x1 + 1] == open_[y0:y1 + 1, x0:x1 + 1]).mean() > 0.999:
        continue                                       # (the page still open as it was)
    # how far down the window still reaches: the frame's left side, at its own x (a hop away: nothing there)
    left = np.nonzero(b[y0:y1 + 1, x0])[0]
    if not len(left) or left.max() + y0 < yb + 4:
        continue                                       # (rolled up over the first row, or gone)
    seen += 1
    now = (head & b[ya:yb, x0 + 4:x1 - 4]).sum()
    if now * 100 < was * 80:
        blank += 1
print(was, seen, blank)
EOF
)
    [[ $r != none ]] || { no "$s: the window did not open"; continue; }
    read -r _ seen blank <<<"$r"
    ((seen >= 3)) || { no "$s: only $seen frames of it closing: nothing to judge"; continue; }
    ((blank == 0)) || no "$s: $blank of $seen closing frames with the first text row blank — a page wiped before it went"
    rm -rf "$d" "$v"
  done
done
((fail)) && exit 1
echo "float-exit: held — books, wallpapers, the git screen, the file dialog: each rolls up with its words, both themes"
