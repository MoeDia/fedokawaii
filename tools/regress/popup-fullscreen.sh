#!/usr/bin/env bash
# tools/regress/popup-fullscreen.sh — never again a popup hidden behind a fullscreen window (bug 9: "popups
# must show over fullscreen windows"): a real fullscreen terminal, each popup opened over it by its key:
# it shows, and closing it gives the fullscreen window back, pixel for pixel (but for its cursor's one
# cell: focus or a blink). Headless (tools/kit.sh, the real GPU).
#   bash tools/regress/popup-fullscreen.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each popup said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-popf.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
keys=(v u n x slash c w a r space)
{
  echo 'panel; warm; nap 1'
  echo 'foot sh -c "echo a fullscreen window; exec sleep 300" & nap 1.2'
  echo 'chord logo f; nap 1; at 300 700; nap 0.3; shot base'
  # (the notes' Esc only leaves typing: their own key puts the page away)
  for k in "${keys[@]}"; do
    close="key Escape"; [[ $k == n ]] && close="chord logo n"
    echo "chord logo $k; nap 1.3; shot on-$k; $close; nap 1.1; shot off-$k"
  done
} >"$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --time 200 --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "popup-fullscreen: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
python3 -I - "$out" "${keys[@]}" <<'PY_END'
import os, sys
import numpy as np
from PIL import Image
out, keys = sys.argv[1], sys.argv[2:]
def load(n):
    p = os.path.join(out, n + ".png")
    if not os.path.exists(p):
        print(f"popup-fullscreen: no shot {n}")
        sys.exit(2)
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)
base = load("base")
bad, least = [], 10 ** 9
if len(np.unique(base[3], axis=0)) != 1:      # (row 3: the bar's hairlines, unless a window covers it all)
    bad.append("the terminal is not fullscreen: the bar shows")
for k in keys:
    on, off = load("on-" + k), load("off-" + k)
    shown = int(np.any(on != base, axis=-1).sum())
    least = min(least, shown)
    if shown < 2000:
        bad.append(f"Super+{k}: nothing over the fullscreen window ({shown} px changed)")
    left = int(np.any(off != base, axis=-1).sum())
    if left > 160:     # (the terminal's cursor: one cell of 8 × 20, focused or blinking)
        bad.append(f"Super+{k}: closing it left {left} px changed")
print("\n".join(f"popup-fullscreen: {b}" for b in bad) if bad else f"popup-fullscreen: held — {len(keys)} popups over a fullscreen window, each at least {least} px, closing gives it back")
sys.exit(1 if bad else 0)
PY_END
