#!/usr/bin/env bash
# tools/regress/wheel-notch.sh — never again a mouse notch handled twice (T23, the master's review 3: under
# Wayland GDK hands a mouse's notch as a step AND as 1.5 of smooth parts — a list moved 7–8 lines a notch):
# Super+/ in the kit, one real wheel notch from tools/vpointer.c (axis_discrete, as libinput and wlroots send
# a mouse's), the list's move measured from two shots (the shift that lines its rows up again).
#   bash tools/regress/wheel-notch.sh [KIT OPTION…]   (--bin bin --repo-art: the repository's state)
# Exit 0 one notch moved the list once (one to three lines) · 1 it moved more, or not at all · 2 could not run
set -u
here=$(cd "$(dirname "$0")/../.." && pwd)
out=$(mktemp -d /dev/shm/regress-wheel.XXXXXX) || exit 2
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
x=$here/tools/protocols/wlr-virtual-pointer-unstable-v1.xml
read -ra wl < <(pkg-config --cflags --libs wayland-client)
wayland-scanner client-header "$x" "$out/vp-protocol.h" && wayland-scanner private-code "$x" "$out/vp-protocol.c" &&
  cc -O2 -o "$out/vpointer" "$here/tools/vpointer.c" "$out/vp-protocol.c" -I"$out" "${wl[@]}" ||
  { echo "wheel-notch: vpointer did not build" >&2; exit 2; }
# (a play gets no caller's variables: the paths written into it)
cat >"$out/notch.play" <<PLAY
panel
chord logo slash
nap 1.5
$out/vpointer move 960 600
nap 0.4
shot before
$out/vpointer wheel 1
nap 0.8
shot after
key Escape
PLAY
bash "$here/tools/kit.sh" "$@" --play "$out/notch.play" --out "$out" --time 60 play >"$out/kit.log" 2>&1 || { echo "wheel-notch: the kit did not run (see $out/kit.log)" >&2; exit 2; }
python3 -I -B - "$out/before.png" "$out/after.png" <<'PY'
import sys
import numpy as np
from PIL import Image
a, b = (np.asarray(Image.open(f).convert("L"), dtype=float)[260:860, 680:1240] for f in sys.argv[1:3])
best = min(range(0, 241), key=lambda d: np.abs(a[d:] - b[:a.shape[0] - d]).mean())
print(f"wheel-notch: one notch moved the list {best} px")
sys.exit(0 if 0 < best <= 60 else 1)
PY
