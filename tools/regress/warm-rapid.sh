#!/usr/bin/env bash
# tools/regress/warm-rapid.sh — never again a press lost on Super+N (r24-9: "Super+N rapid toggle"; 3 presses in
# 163 ms must toggle three times): the warm windows of a real dwl, their key pressed in bursts in one
# process, 20 ms apart: shown after an odd number of presses, put away after an even one. Super+N, V, U.
#   bash tools/regress/warm-rapid.sh [KIT OPTION…]
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-warmr.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
{
  echo 'panel; warm; nap 2; at 300 700; shot base'
  echo 'burst() { local a=(-s 300) i; for ((i = 0; i < $2; i++)); do a+=(-M logo -k "$1" -m logo -s 20); done; wtype "${a[@]}"; nap 1.2; }'
  for k in n v u; do
    for n in 1 2 3 4 5; do
      echo "burst $k $n; shot $k-$n"
      ((n % 2)) && echo "burst $k 1"    # (put away again, to begin the next from none)
    done
  done
} >"$out/play.sh"
bash "$here/../kit.sh" --theme dark "$@" --time 160 --out "$out" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "warm-rapid: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
python3 -I - "$out" <<'PY_END'
import os, sys
import numpy as np
from PIL import Image
out = sys.argv[1]
def load(n):
    p = os.path.join(out, n + ".png")
    if not os.path.exists(p):
        print(f"warm-rapid: no shot {n}")
        sys.exit(2)
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.int16)
base = load("base")[40:]
bad = []
for k in "nvu":
    for n in range(1, 6):
        moved = int(np.any(load(f"{k}-{n}")[40:] != base, axis=-1).sum())
        shown = moved > 2000
        if shown != bool(n % 2):
            bad.append(f"Super+{k} pressed {n} times: {'shown' if shown else 'put away'} ({moved} px)")
print("\n".join(f"warm-rapid: {b}" for b in bad) if bad else "warm-rapid: held — Super+N, V and U pressed 1 to 5 times, 20 ms apart: every press counted")
sys.exit(1 if bad else 0)
PY_END
