#!/usr/bin/env bash
# tools/regress/warm-exit.sh — never again (r27-16, bug 6: the clipboard's exit flashed a wiped
# terminal — "terminated" — before it went): the warm clipboard (Super+V) opened in a headless
# dwl (tools/kit.sh, the real GPU, both themes), closed by Esc and by Enter, and each closing
# frame looked at — dwl's ghost of the window must be its page as it was: the heading, the
# rows, the cursor's fill — never a blank terminal with a lone cursor.
#   bash tools/regress/warm-exit.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-warm.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
for t in "the first line of a poem about ink" "rm -rf ~/tmp/old" "15% of 2400 = 360"; do printf '%s' "$t" | cliphist store; done
warm
nap 1
chord logo v
nap 2.5
shot open
key Escape
nap 0.04
shot esc
nap 1.5
chord logo v
nap 2
key Return
nap 0.04
shot enter
PLAY
fail=0
no() { echo "warm-exit ($th): $*" >&2; fail=1; }
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "warm-exit: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  for f in esc enter; do
    # the page's ink in the window's box, against the open window's: a ghost keeps nearly all
    # of it (it fades: an ink a little off still counts); a wiped terminal keeps none
    m=$(python3 -I - "$out/$th/open.png" "$out/$th/$f.png" <<'EOF'
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert("RGB"); b = Image.open(sys.argv[2]).convert("RGB")
W, H = a.size; g = a.getpixel((5, H - 5))
far = lambda c: sum(abs(x - y) for x, y in zip(c, g)) > 60
box = [(x, y) for y in range(40, H, 3) for x in range(0, W, 3) if far(a.getpixel((x, y)))]
if not box:
    print("none"); sys.exit()
x0 = min(p[0] for p in box); x1 = max(p[0] for p in box); y0 = min(p[1] for p in box); y1 = max(p[1] for p in box)
def ink(im, dy=0):
    return sum(1 for y in range(y0 + 8, y1 - 8, 2) for x in range(x0 + 8, x1 - 8, 2)
               if 0 <= y + dy < H and far(im.getpixel((x, y + dy))))
# (the ghost sinks a few pixels a frame: the best of a few offsets)
best = max(ink(b, dy) for dy in range(0, 40, 2))
print(ink(a), best)
EOF
)
    [[ $m != none ]] || { no "the clipboard did not open"; break; }
    read -r was now <<<"$m"
    ((now * 100 >= was * 60)) || no "closing by $f: $now of the page's $was ink points left — a page wiped before it went"
  done
done
((fail)) && exit 1
echo "warm-exit: held — Esc and Enter: the clipboard's ghost is its page as it was, both themes"
