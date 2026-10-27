#!/usr/bin/env bash
# tools/regress/warm-exit.sh — never again (r27-16, bug 6: the clipboard's exit flashed a wiped
# terminal — "terminated" — before it went): the warm clipboard (Super+V) opened in a headless
# dwl (tools/kit.sh, the real GPU, both themes), closed by Esc and by Enter, and each closing
# frame looked at — dwl's ghost of the window must be its page as it was: the heading, the
# rows, the cursor's fill — never a blank terminal with a lone cursor. (Put away, the page rolls
# up into its top edge, frozen as it stood — T19: whatever is still open above its rod is the
# open page's own rows, pixel for pixel.)
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
# (the rod: the lowest row with ink across most of the page — the frame's foot, where the scroll
# is open to; above it, the closing frame's ink must be the open page's — a wiped terminal keeps
# none of the heading's)
def across(y):
    return sum(1 for x in range(x0, x1, 3) if far(b.getpixel((x, y)))) > 0.8 * (x1 - x0) / 3
rod = max((y for y in range(y0, y1 + 1) if across(y)), default=y0)
ya, yb = y0 + 8, rod - 3
if yb - ya < 12:
    print("late"); sys.exit()
both = was = 0
for y in range(ya, yb):
    for x in range(x0 + 8, x1 - 8, 2):
        fa, fb = far(a.getpixel((x, y))), far(b.getpixel((x, y)))
        was += fa
        both += fa and fb
print(was, both)
EOF
)
    [[ $m != none ]] || { no "the clipboard did not open"; break; }
    [[ $m != late ]] || { no "closing by $f: the shot came after the scroll had all but closed — nothing to judge"; continue; }
    read -r was now <<<"$m"
    ((was > 0 && now * 100 >= was * 90)) || no "closing by $f: $now of the open page's $was ink points above the rod — a page wiped before it went"
  done
done
((fail)) && exit 1
echo "warm-exit: held — Esc and Enter: the clipboard rolls up as its page was, both themes"
