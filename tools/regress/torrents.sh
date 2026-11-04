#!/usr/bin/env bash
# tools/regress/torrents.sh — never again (T29: "nothing cut or misaligned at any size"): Torrents' window in a headless dwl
# (tools/kit.sh: the real GPU, foot and its fonts, both moods), a mock engine saying every state at once
# (tests/engine/torrents_mock.py), at a narrow tile, half the screen and the whole of it, measured against
# docs/design-system.md §7, to the pixel:
#   · the cursor: 20 px on the row grid, tinted from the cursor's column to the window's last, the token's colour; its first 2 px the edge
#   · the tab's vermilion line under its name alone, flush with the letters
#   · a heading's rule on the cell's tenth pixel row, and how much the part holds ending in the last content column
#   · a row's icon in its column, the right margin free of ink but for the cursor
#   · the meter: ten segments, 6 px wide on an 8 px pitch, 10 tall; part-way a dissolve's pixels, never a smear
#   · the details' rail whole from the top to the keys' line, on the list's far side (whole-screen only)
#   bash tools/regress/torrents.sh [KIT OPTION…]   (--bin bin --repo-art: the repository's state; KEEP=1 keeps the shots)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$(mktemp -d /dev/shm/regress-torrents.XXXXXX)
[[ ${KEEP:-} == 1 ]] && echo "shots: $out" || trap 'rm -rf "$out"' EXIT
export PATH=$HOME/.local/bin:$PATH
cat >"$out/check.py" <<'EOF'
import sys
import numpy as np
from PIL import Image
path, theme, cols, rows, foot = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
# the inks: foot's palette past the sixteen, as the window asks for them (term.py)
NAMES = {16: "ACCENT", 19: "EDGE2", 20: "ACCENT_TEXT", 24: "SELECT"}
ink, section = {}, ""
for line in open(foot, encoding="utf-8"):
    line = line.strip()
    if line.startswith("["):
        section = line
    elif section == f"[colors-{theme}]" and "=" in line:
        k, v = line.split("=", 1)
        if k.isdigit() and int(k) in NAMES:
            ink[NAMES[int(k)]] = np.array([int(v[i:i + 2], 16) for i in (0, 2, 4)])
a = np.asarray(Image.open(path).convert("RGB")).astype(int)
near = lambda name, tol=10: np.abs(a - ink[name]).sum(axis=2) <= tol
bad = []
def no(msg):
    bad.append(msg)
acc = near("ACCENT")
hr = np.nonzero(acc.sum(axis=1) > 200)[0]; hc = np.nonzero(acc.sum(axis=0) > 200)[0]
if len(hr) < 2 or len(hc) < 2:
    print("the window's hairline was not found"); sys.exit(1)
X0, Y0 = hc[0] + 1 + 8, hr[0] + 1 + 8                 # the first cell: the hairline, foot's 8 px
Xe, Ye = hc[-1] - 8, hr[-1] - 8
if Xe - X0 != 8 * cols:
    no(f"the window holds {(Xe - X0) / 8} columns, not {cols}")
if Ye - Y0 != 20 * rows:
    no(f"the window holds {(Ye - Y0) / 20} rows, not {rows}")
col = lambda c: X0 + 8 * c
row = lambda r: Y0 + 20 * r
# the cursor: a whole row of the grid, tinted; its first 2 px the edge, the seal's red, 20 tall, nothing beside it
sel = near("SELECT")
ys = [y for y in range(Y0, Ye) if sel[y, X0:Xe].sum() > 8 * cols // 3]
if not ys:
    no("no cursor's row")
else:
    if len(ys) != 20 or (ys[0] - Y0) % 20:
        no(f"the cursor's tint is {len(ys)} px tall, at {(ys[0] - Y0) % 20} px off the grid")
    xs = np.nonzero(sel[ys[0]])[0]
    pane = cols >= 132
    if not pane and (xs[0] != X0 + 2 or xs[-1] != Xe - 1):
        no(f"the cursor's tint runs {xs[0] - X0} … {xs[-1] - X0}, not 2 … {8 * cols - 1}")
    if pane and xs[0] != X0 + 2:
        no(f"the cursor's tint starts {xs[0] - X0} px in")
    edge = near("ACCENT")[ys[0]:ys[0] + 20, X0 - 1:X0 + 3]
    if not edge[:, 1:3].all() or edge[:, 0].any() or edge[:, 3].any():
        no("the cursor's edge is not 2 px of the seal's red, the row's 20 tall")
# the tab's line: under "downloads" alone: columns 4 … 12, at the top of the row after the tabs
line = near("ACCENT")[row(1) : row(1) + 3, X0 : col(40)]
ly, lx = np.nonzero(line)
if not len(lx):
    no("no vermilion line under the tab")
else:
    if lx.min() != 8 * 4 or lx.max() != 8 * 13 - 1:
        no(f"the tab's line runs {lx.min()} … {lx.max()} px, not {8 * 4} … {8 * 13 - 1}")
# a heading's rule: the first heading stands on row 3, its rule on the cell's tenth pixel row (foot's own line), to the
# list's last content column
list_w = cols - 2 - 60 - 3 if cols >= 132 else cols - 2
rule = near("EDGE2", 6)[row(3) + 9]
xs = np.nonzero(rule[X0:X0 + 8 * (list_w + 1)])[0]
if not len(xs):
    no("no rule on the heading's tenth pixel row")
elif xs.max() - xs.min() < 8 * 8:
    no(f"the rule is only {xs.max() - xs.min()} px long")
# (then how much the part holds, its ink ending inside the last content column)
head = np.abs(a[row(3) + 2:row(3) + 18, X0:X0 + 8 * (list_w + 2)] - a[Ye - 1, Xe - 1]).sum(axis=2) > 30
ends = np.nonzero(head.sum(axis=0))[0]
if not len(ends) or not 8 * list_w <= ends.max() <= 8 * (list_w + 1):
    no(f"the heading's row ends at {ends.max() if len(ends) else None} px, not in column {list_w}")
# nothing but the cursor's tint in the right margin column (the whole-screen one: the same at the pane's end; a letter's own
# overhang of a pixel, as % has, is the font's)
ground = a[Ye - 1, Xe - 1]
margin = np.abs(a[Y0:Ye, col(cols - 1) + 1:Xe] - ground).sum(axis=2) > 12
for r in range(rows):
    part = margin[20 * r:20 * r + 20]
    if part.any() and not sel[row(r) + 1, col(cols - 1)]:
        no(f"ink in the right margin on row {r}")
# the meter (where a row has one): the Night of the Living Dead row, row 7 of the mock's list: its first four segments, solid
if cols >= 64:
    r = 7
    t = near("ACCENT_TEXT", 12)[row(r) + 2:row(r) + 18, col(30):Xe]
    seg_cols = np.nonzero(t.sum(axis=0) >= 8)[0]
    if len(seg_cols) >= 18:
        runs, start = [], seg_cols[0]
        for u, v in zip(seg_cols, seg_cols[1:]):
            if v != u + 1:
                runs.append((start, u)); start = v
        runs.append((start, seg_cols[-1]))
        runs = runs[:4]                            # (the solid ones: 43 % of ten; the fifth is part-way)
        wid = {b - x + 1 for x, b in runs}
        if wid != {6}:
            no(f"meter segments {sorted(int(w) for w in wid)} px wide")
        pitch = {runs[k + 1][0] - runs[k][0] for k in range(len(runs) - 1)}
        if pitch != {8}:
            no(f"meter pitch {sorted(int(p) for p in pitch)} px")
        ty = np.nonzero(t[:, runs[0][0]])[0]
        if ty.max() - ty.min() + 1 != 10:
            no(f"a segment {ty.max() - ty.min() + 1} px tall")
    elif cols >= 86:
        no("no meter on the row that has one")
if cols >= 132:
    rail = 1 + 0 + (cols - 2 - 60 - 3) + 1
    r_col = col(rail)
    e = near("EDGE2", 6)[:, r_col:r_col + 8]
    miss = [r for r in range(rows - 1) if not e[row(r):row(r) + 20].any()]
    if miss:
        no(f"the rail is missing on rows {miss[:5]}")
    head = np.abs(a[row(0) + 5:row(0) + 15, col(rail + 2):col(rail + 4)] - ground).sum(axis=2) > 30
    if not head.any():
        no("no pane heading at the rail's second column")
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
EOF
fail=0
for th in dark light; do
  for size in 60x34 116x34 236x50; do
    cols=${size%x*} rows=${size#*x}
    scene=$out/scene-$th-$size.sh
    cat >"$scene" <<SCENE
#!/usr/bin/env bash
export KAWA_TORRENTS_LIB=$repo/configs/home/.local/lib/fedokawaii/kawa-torrents KAWA_PROWLARR_URL=http://127.0.0.1:0
python3 -I $repo/tests/engine/torrents_mock.py &
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do [ -S "\$XDG_RUNTIME_DIR/kawa-torrents.sock" ] && break; sleep 0.1; done
exec python3 $repo/bin/kawa-torrents
SCENE
    d=$out/$th-$size
    if ! bash "$here/../kit.sh" --theme "$th" "$@" --tui "$size:$scene" --tui-wait 3 --out "$d" --time 60 tui >"$d.log" 2>&1; then
      echo "torrents: the kit failed: $(tail -n 2 "$d.log")" >&2; exit 2
    fi
    if ! m=$(python3 -I "$out/check.py" "$d/tui.png" "$th" "$cols" "$rows" "$repo/configs/home/.config/foot/foot.ini" 2>&1); then
      echo "torrents ($th, $size): $m" >&2; fail=1
    fi
  done
done
((fail)) || echo "torrents: held, both moods, a narrow tile to the whole screen"
exit "$fail"
