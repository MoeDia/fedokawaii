#!/usr/bin/env bash
# tests/static/test_masters.sh — the desktop's own pictures as committed (art/masters/out, made by
# tools/build-masters.py; the master's T18 review 1, must-fix 4: nothing read them): each one the
# list names is there with the list's SHA-256 (a rebuild without the list's new hash, or the other
# way round, shows here), 640 × 360, indexed, its palette exactly its mood's inks (build-masters'
# PALETTE) and every pixel one of them.
. "$(dirname "$0")/../lib/harness.sh"

LIST=$REPO/configs/home/.local/share/fedokawaii/wallpapers.list
OUT=$REPO/art/masters/out

case_ "every picture the list takes from the toolkit is committed, with the list's SHA-256 — and no other is"
listed=$(awk '($1 == "dark" || $1 == "light") && $6 ~ /^toolkit:art\/masters\/out\// { print $2 }' "$LIST" | sort)
there=$(cd "$OUT" && ls -1 -- *.png | sed 's/\.png$//' | sort)
bad=$(awk '($1 == "dark" || $1 == "light") && $6 ~ /^toolkit:/ { print $5 "  " substr($6, 9) }' "$LIST" \
  | (cd "$REPO" && sha256sum --quiet -c - 2>&1))
[[ -n $listed && $listed == "$there" && -z $bad ]] && _ok \
  || _no "listed ≠ committed (list: $(wc -w <<<"$listed"), files: $(wc -w <<<"$there")) or hashes: $bad"

case_ "each 640 × 360, indexed, its palette its mood's inks and nothing else, every pixel one of them"
out=$(python3 -I -B - "$REPO" "$LIST" <<'PY'
import importlib.util, sys
from pathlib import Path
from PIL import Image
repo, lst = Path(sys.argv[1]), sys.argv[2]
spec = importlib.util.spec_from_file_location("build_masters", repo / "tools/build-masters.py")
bm = importlib.util.module_from_spec(spec); spec.loader.exec_module(bm)
inks = {m: [round(c * 255) for c in bm.hexes(bm.PALETTE[m]).flatten().tolist()] for m in bm.PALETTE}
for line in open(lst):
    f = line.split()
    if len(f) < 6 or f[0] not in ("dark", "light") or not f[5].startswith("toolkit:art/masters/out/"):
        continue
    im = Image.open(repo / f[5][len("toolkit:"):])
    n = len(inks[f[0]]) // 3
    pal = im.getpalette()[:3 * n] if im.mode == "P" else None
    used = im.getextrema()[1] if im.mode == "P" else None
    if im.size != (640, 360) or im.mode != "P" or pal != inks[f[0]] or used >= n:
        print(f"{f[1]}: {im.size} {im.mode}, palette {'ok' if pal == inks[f[0]] else 'not ' + f[0] + 's'}, index up to {used} of {n}")
PY
)
[[ $? -eq 0 && -z $out ]] && _ok || _no "$out"

case_ "no paper at any picture's edges: no print margin, frame line or mount left at a side (build-masters' edge check; the master's T18 review 1, must-fix 1)"
out=$(cd "$REPO" && python3 -I -B tools/build-masters.py --check "$OUT"/*.png 2>&1)
[[ $? -eq 0 && -z $out ]] && _ok || _no "$out"
done_
