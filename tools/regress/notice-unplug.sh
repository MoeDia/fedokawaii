#!/usr/bin/env bash
# tools/regress/notice-unplug.sh — never again (r27-stuck-notice, 2 Nov: "recording ×4" stayed on
# his screen for hours, drawn by no client — mako restarted under it): a screen dropped off the
# cable while a notice showed on it, and dwl's ghost of that notice (it dissolves away as it
# unmaps) outlived the monitor it belonged to — no frame of a monitor that is gone ever ended it,
# and it lay in the scene where the screen had been. Here: a nested dwl (the wayland backend:
# each screen a window of a headless kit dwl, tools/hl-dwl.sh) with two screens, mako pinned to
# the second, a critical notice on it; that screen's window closed (its output destroyed, as an
# HDMI screen switched off at its button), every notice dismissed — where the notice was, the
# screen that is left must show the bare ground.
#   bash tools/regress/notice-unplug.sh [--dwl BIN]   (default the edited tree's ~/.local/src/dwl/dwl)
# Exit 0 held · 1 broken (said) · 2 could not run here
set -u
here=$(cd "$(dirname "$0")" && pwd)
bin=$HOME/.local/src/dwl/dwl
[[ ${1:-} == --dwl ]] && bin=$2
[[ -x $bin ]] || { echo "notice-unplug: no dwl at $bin" >&2; exit 2; }
out=$(mktemp -d /dev/shm/regress-unplug.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
rt=$XDG_RUNTIME_DIR
printf '#!/bin/sh\necho "$WAYLAND_DISPLAY" >"$XDG_RUNTIME_DIR/b-up"\nexec sleep 600\n' >"$rt/b-inside.sh"
WLR_BACKENDS=wayland WLR_WL_OUTPUTS=2 "$BDWL" -s "sh $rt/b-inside.sh" >"$OUT/b-dwl.log" 2>&1 &
bpid=$!
i=0
while [ ! -s "$rt/b-up" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
B=$(cat "$rt/b-up")
sleep 2
# (the kit dwl focuses the window mapped last, B's second screen: the one Super+Q closes)
{ echo "output=WL-2"; cat "$HOME/.config/mako/config"; } >"$rt/mako.conf"
WAYLAND_DISPLAY=$B mako -c "$rt/mako.conf" >"$OUT/mako.log" 2>&1 &
sleep 1
notify-send -u critical -a desktop recording "the recording did not start"
sleep 1.5
WAYLAND_DISPLAY=$B grim "$OUT/before.png"
wtype -s 1000 -M logo -k q -m logo
sleep 1.5
makoctl dismiss --all
sleep 1.5
makoctl list >"$OUT/left.txt" 2>&1
WAYLAND_DISPLAY=$B wlr-randr >"$OUT/screens.txt" 2>&1
WAYLAND_DISPLAY=$B grim "$OUT/after.png"
kill "$bpid"
PLAY
OUT=$out BDWL=$bin bash "$here/../hl-dwl.sh" "$out/play.sh" --dwl "$bin" --time 60 >"$out/kit.log" 2>&1 \
  || { echo "notice-unplug: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
[[ -s $out/before.png && -s $out/after.png ]] || { echo "notice-unplug: no shots (the nested dwl did not run)" >&2; exit 2; }
grep -q '^WL-2 ' "$out/screens.txt" && { echo "notice-unplug: the notice's screen was not the one closed" >&2; exit 2; }
[[ -s $out/left.txt ]] && { echo "notice-unplug: mako still lists a notice" >&2; exit 2; }
python3 -I - "$out/before.png" "$out/after.png" <<'EOF'
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert("RGB"); b = Image.open(sys.argv[2]).convert("RGB")
g = a.getpixel((5, a.size[1] - 5))
far = lambda c: sum(abs(x - y) for x, y in zip(c, g)) > 60
box = [(x, y) for y in range(a.size[1]) for x in range(a.size[0]) if far(a.getpixel((x, y)))]
if not box:
    print("notice-unplug: no notice on the screen before it was closed", file=sys.stderr); sys.exit(2)
x0, x1 = min(p[0] for p in box), max(p[0] for p in box)
y0, y1 = min(p[1] for p in box), max(p[1] for p in box)
left = sum(1 for y in range(y0, y1 + 1) for x in range(x0, min(x1 + 1, b.size[0])) if far(b.getpixel((x, y))))
if left:
    print(f"notice-unplug: the notice's picture stayed after its screen went ({left} px in {x0},{y0}–{x1},{y1})")
    sys.exit(1)
print(f"notice-unplug: held — the ground where the notice was ({x0},{y0}–{x1},{y1})")
EOF
