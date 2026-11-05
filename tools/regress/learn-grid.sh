#!/usr/bin/env bash
# tools/regress/learn-grid.sh — never again (T27): the lessons on the design system's grid, to the pixel, in both
# moods. A headless kit (the real GPU, nothing of the session): the list and a lesson in a window of 118 × 40. From the
# window's left hairline: the cursor's lacquer at +17 (§7), a heading's icon at +25, a row's mark at +33; a row 20 px;
# a heading's rule on its row's pixel 10, ending where the rows' times do; the list and its pane unmoved between the
# moods (a theme is inks, never geometry); a lesson's seal painted whole, in the mood's accent, its halves mirrored,
# and every stamp a thump larger for a moment only; the page's rule vermilion as far as it was read.
#   bash tools/regress/learn-grid.sh [KIT OPTION…]   (e.g. --bin bin --repo-art --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (what, said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
out=$(mktemp -d /dev/shm/regress-learn.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT   # (KEEP=1: the shots kept, the folder said)
cat >"$out/play.sh" <<PLAY
mkdir -p "\$HOME/.local/state/fedokawaii"
printf 'how-to-read\t2026-11-01\nthe-plan\t2026-11-01\n' >"\$HOME/.local/state/fedokawaii/learn"
footclient -a float -T lessons -W 118x41 -- env KAWA_LEARN=$repo/docs/learn kawa-learn >/dev/null 2>&1 &
nap 1.5
shot list
key Up; key Up; nap 0.4
shot stamped
key Return; nap 0.6
key End; nap 0.4
shot end
say "\$(readlink "\$HOME/.config/fedokawaii/current")"
PLAY
for th in dark light; do
  mkdir -p "$out/$th"
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "learn-grid: the kit failed ($th): $(tail -n 1 "$out/kit-$th.log")" >&2; exit 2; }
done
python3 -I - "$out" "$repo" <<'PY'
import re, sys
from PIL import Image
out, repo = sys.argv[1:3]
bad = []
geo = {}
def hexs(p): return "%02x%02x%02x" % p
for th in ("dark", "light"):
    t = f"{repo}/configs/home/.config/fedokawaii/themes/{th}"
    pal = dict(re.findall(r"^C_(\w+)=([0-9a-f]{6})", open(f"{t}/colors.sh").read(), re.M))
    pal["SELECT"] = re.search(r"^select=#?([0-9a-f]{6})", open(f"{t}/panel.conf").read(), re.M)[1]
    im = Image.open(f"{out}/{th}/stamped.png").convert("RGB"); W, H = im.size; px = im.load()
    ground = px[5, H - 5]
    # the window: its left hairline, the first column that differs under the bar
    y = H // 2
    left = next(x for x in range(W) if px[x, y] != ground)
    top = next(j for j in range(40, H) if px[W // 2, j] != ground)
    # the lacquer: the row that holds the select ink
    sel = next(((x, j) for j in range(top, H) for x in range(left, W // 2) if hexs(px[x, j]) == pal["SELECT"]), None)
    if not sel:
        bad.append(f"{th}: no cursor row"); continue
    lac_x, lac_y = sel
    if lac_x - left != 17:
        bad.append(f"{th}: the lacquer starts {lac_x - left} px from the hairline, not 17")
    lac_h = sum(1 for j in range(lac_y, lac_y + 30) if hexs(px[lac_x, j]) == pal["SELECT"])
    if lac_h != 20:
        bad.append(f"{th}: the cursor's row is {lac_h} px high, not 20")
    if (lac_y - top - 9) % 20:
        bad.append(f"{th}: the row's top {lac_y - top} is not on the 20 px grid from the window's top")
    lac_end = max(x for x in range(lac_x, W) if hexs(px[x, lac_y]) == pal["SELECT"])
    # a heading's rule: the edge2 run on a row above, its pixel 10
    rule = None
    for j in range(H - 1, lac_y, -1):         # (the lowest heading: no stamp yet in its chapter, nothing after its rule)
        run = [x for x in range(lac_x, lac_end + 1) if hexs(px[x, j]) == pal["EDGE2"]]
        if len(run) > 60:
            rule = (j, run[0], run[-1]); break
    if not rule:
        bad.append(f"{th}: no heading's rule above the row")
    else:
        if (rule[0] - top - 9) % 20 != 9:     # (counted from 0: §3's row 10, foot's box drawing)
            bad.append(f"{th}: the rule on pixel {(rule[0] - top - 9) % 20} of its row, not 9")
        if lac_end - rule[2] != 8:
            bad.append(f"{th}: the rule ends {lac_end - rule[2]} px before the lacquer's end, not one cell (8)")
    # a heading's icon at +25: the accent_text ink starts there (on its row, its 12 px icon centred in 16)
    head = rule[0] if rule else lac_y
    ink = [x for x in range(left + 2, left + 60) for j in range(head - 8, head + 8) if hexs(px[x, j]) == pal["ACCENT_TEXT"]]
    if not ink or not 25 <= min(ink) - left <= 29:
        bad.append(f"{th}: the heading's icon at +{min(ink) - left if ink else 'none'}, not in its column at +25")
    # the seal beside the list: the accent ink, whole and mirrored
    # (the pane's middle: not the window's hairline, not its heading's icon, which in the light mood are this ink)
    # (a sixel's colours are whole percents: within two of it)
    want = tuple(int(pal["ACCENT"][i:i + 2], 16) for i in (0, 2, 4))
    near = lambda p: all(abs(a - b) <= 2 for a, b in zip(p, want))
    pane = [(x, j) for j in range(top + 60, top + 700) for x in range(left + 500, left + 900) if near(px[x, j])]
    if not pane:
        bad.append(f"{th}: no stamp beside a stamped lesson")
    else:
        x0, x1 = min(p[0] for p in pane), max(p[0] for p in pane)
        y0, y1 = min(p[1] for p in pane), max(p[1] for p in pane)
        if x1 - x0 + 1 > 56:
            bad.append(f"{th}: the stamp {x1 - x0 + 1} px wide")
        ps = set(pane)
        if any((x0 + x1 - x, j) not in ps for x, j in pane):
            bad.append(f"{th}: the stamp's halves are not mirrored")
    geo[th] = (left, top, lac_x, lac_y, lac_end, rule)
    # the end of a lesson: the seal again, the head's rule all vermilion
    e = Image.open(f"{out}/{th}/end.png").convert("RGB"); p2 = e.load()
    row = next((j for j in range(top, top + 80) if sum(1 for x in range(left, left + 980) if hexs(p2[x, j]) == pal["ACCENT"]) > 200), None)
    if row is None:
        bad.append(f"{th}: at a lesson's end its heading's rule is not vermilion to its end")
    elif any(hexs(p2[x, row]) == pal["EDGE2"] for x in range(left, left + 980)):
        bad.append(f"{th}: at a lesson's end part of the rule is still unread")
if geo.get("dark") != geo.get("light"):
    bad.append(f"the moods differ in geometry: {geo}")
print("\n".join("learn-grid: " + b for b in bad) if bad else "learn-grid: held — lacquer +17, rows 20, rule on 10, the stamp whole, both moods alike")
sys.exit(1 if bad else 0)
PY
rc=$?
[[ ${KEEP:-} == 1 ]] && echo "learn-grid: shots kept in $out"
exit "$rc"
