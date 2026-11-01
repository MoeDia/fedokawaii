#!/usr/bin/env bash
# tools/regress/notes-page.sh — never again (r27-21, his line 39: "the spacing on the top margin and
# bottom margin … stays consistent no matter how far I have typed or how much scrolling is happening"):
# Super+N's page in a headless dwl (tools/kit.sh, the real GPU, both themes), 40 lines typed into it at a
# typist's pace (two of them wrapping) while every screen change is recorded, and each frame looked at:
# the head (heading, its blank row), the foot (the blank row, the footer) and the margin column exactly
# as the page opened, every ruled row's rule whole, the page scrolling one row at a time and nothing
# else, and at the end three ruled rows of fresh paper still ahead of the pen.
#   bash tools/regress/notes-page.sh [KIT OPTION…]   (--bin bin --repo-art: the repository's state —
#   then the repository's notes.lua too, which the kit's home does not carry)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-notes.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
lua=
for a in "$@"; do [[ $a == --repo-art ]] && lua=$here/../../configs/home/.config/fedokawaii/notes.lua; done
fail=0
no() { echo "notes-page ($th): $*" >&2; fail=1; }
for th in dark light; do
  # shellcheck disable=SC2016  # (the play's own $HOME, expanded inside the kit)
  { [[ -n $lua ]] && printf 'cp %q "$HOME/.config/fedokawaii/notes.lua"\n' "$(realpath "$lua")"
    printf 'rec=%q\n' "$out/$th.mkv"
    cat <<'PLAY'
mkdir -p "$HOME/Notes"
printf '# notes\n\n## 2026-10-31 · Sat\n\nthe first day\n\n## 2026-11-01 · Sun\n\nrenew the passport\nbuy rice\n' >"$HOME/Notes/notes.md"
warm
nap 3
chord logo n
nap 2
shot open
wf-recorder -c libx264rgb -p crf=0 -p preset=ultrafast -f "$rec" >/dev/null 2>&1 &
w=$!
nap 1.5
for i in $(seq 1 40); do
  case $i in
    12|27) wtype -d 22 -- "line $i is a long one: it runs past the page's right edge and wraps onto a second ruled row of paper" ;;
    *) wtype -d 22 -- "line $i of the typing play, written at pace" ;;
  esac
  wtype -k Return
done
nap 1.5
kill -INT $w; wait $w 2>/dev/null
shot typed
PLAY
  } >"$out/play-$th.sh"
  bash "$here/../kit.sh" --theme "$th" "$@" --time 300 --out "$out/$th" --play "$out/play-$th.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "notes-page: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  [[ -s $out/$th.mkv && -s $out/$th/open.png && -s $out/$th/typed.png ]] || { no "the page did not open, or nothing was recorded"; continue; }
  while IFS= read -r line; do no "$line"; done < <(python3 -I - "$out/$th/open.png" "$out/$th/typed.png" "$out/$th.mkv" <<'EOF'
import subprocess, sys
import numpy as np
from PIL import Image
a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(np.int16)
H, W, _ = a.shape; g = a[H - 5, 5]
far = np.abs(a - g).sum(axis=2) > 60
ys, xs = np.nonzero(far[40:]); ys = ys + 40               # (the window: everything off the ground under the bar)
if not len(ys): print("the page did not open"); sys.exit()
X0, X1, Y0, Y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
o = a[Y0:Y1, X0:X1]; h, w, _ = o.shape
cols, cnt = np.unique(o.reshape(-1, 3), axis=0, return_counts=True); ground = cols[cnt.argmax()]   # (the paper)
# the rules: rows drawn across in one ink that is not the paper, from the text's column to the page's edge
rules = []
for y in range(h):                                        # (the longest run of one ink not the paper's, in each row)
    row = o[y]; c = row[w // 2]
    if np.all(c == ground): continue
    same = np.concatenate(([0], np.all(row == c, axis=1).astype(np.int8), [0]))
    edges = np.flatnonzero(np.diff(same)); starts, ends = edges[::2], edges[1::2]
    k = int(np.argmax(ends - starts))
    if ends[k] - starts[k] > 0.8 * w: rules.append((y, int(starts[k]), int(ends[k]), tuple(int(v) for v in c)))
page = [r for r in rules if r[3] == rules[len(rules) // 2][3]] if rules else []
if len(page) < 30: print(f"the page is not ruled ({len(page)} rules)"); sys.exit()
gaps = [b[0] - a_[0] for a_, b in zip(page, page[1:])]
cell = max(set(gaps), key=gaps.count)                      # (the cell's height: most rules are one apart)
page = [r for r in page if (page[-1][0] - r[0]) % cell == 0]   # (the heading's own rule is not the paper's)
step = {b[0] - a_[0] for a_, b in zip(page, page[1:])}
if step != {cell}: print(f"the rules are not one to a row ({sorted(step)} px apart, the row {cell})")
rule_y = [r[0] for r in page]; x0, x1 = page[0][1], page[0][2]; RULE = np.array(page[0][3])
top = rule_y[0] - (cell - 2); rows = len(rule_y); bot = top + cell * rows
p = subprocess.Popen(["ffmpeg", "-v", "error", "-i", sys.argv[3], "-fps_mode", "passthrough", "-vf",
                      f"crop={w}:{h}:{X0}:{Y0}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
ref = prev = None; n = moved = 0; broke = []; shifts = {}
while True:
    b = p.stdout.read(w * h * 3)
    if len(b) < w * h * 3: break
    f = np.frombuffer(b, np.uint8).reshape(h, w, 3).astype(np.int16)
    if ref is None: ref = f
    if np.any(f[:top] != ref[:top]) or np.any(f[bot:] != ref[bot:]) or np.any(f[top:bot, :x0] != ref[top:bot, :x0]): moved += 1
    worst = max(int(np.any(f[y, x0:x1] != RULE, axis=1).sum()) for y in rule_y)
    if worst > 3: broke.append(n)
    if prev is not None:
        t, q = f[top:bot], prev[top:bot]
        changed = sum(np.any(t[cell * k:cell * k + cell] != q[cell * k:cell * k + cell]) for k in range(rows))
        if changed > 3:                                    # a scroll: by how many rows the page moved
            best = max(((s, sum(np.array_equal(t[cell * k:cell * (k + 1)], q[cell * (k + s):cell * (k + s + 1)])
                                for k in range(rows) if 0 <= k + s < rows)) for s in range(-4, 5) if s), key=lambda v: v[1])
            shifts[best[0]] = shifts.get(best[0], 0) + 1
    prev = f; n += 1
p.wait()
if n < 500: print(f"only {n} frames recorded — the typing did not reach the page")
if moved: print(f"{moved} of {n} frames moved the head, the foot or the margin")
if broke: print(f"{len(broke)} of {n} frames broke a rule (first: frame {broke[0]})")
if set(shifts) - {1}: print(f"the page scrolled by other than one row: {shifts}")
if shifts.get(1, 0) < 5: print(f"the page hardly scrolled ({shifts}) — the play did not fill it")
e = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(np.int16)[Y0:Y1, X0:X1]
inked = [k for k in range(rows) if np.any(np.abs(e[top + cell * k:top + cell * k + cell - 2, x0:x1] - ground).sum(axis=2) > 60)]
ahead = rows - 1 - max(inked) if inked else 0
if ahead < 3: print(f"at the end only {ahead} ruled row(s) of paper ahead of the pen (3 wanted)")
EOF
)
done
((fail)) && exit 1
echo "notes-page: held — the page's head, foot and margin still in every frame, its rules whole, one row a scroll, paper ahead of the pen, both themes"
