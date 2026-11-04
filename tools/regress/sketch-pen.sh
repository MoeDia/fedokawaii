#!/usr/bin/env bash
# tools/regress/sketch-pen.sh — never again: Sketch's pen. FireAlpaca, the installed one with its skin, off the
# screen on a dwl built here with a tablet of nothing fed through a FIFO: the pressure goes the whole
# way a real pen's does (wlr_tablet → dwl's tablet-v2 → Xwayland's stylus → Qt → the brush). Three strokes of
# one pressure each are measured on the shot, with the default brush and the mouse parked off the window: 0.10
# thinner than 0.50, 0.50 thinner than 1.00, the thinnest no more than a third of the thickest; a stroke's tail
# (kawa-firealpaca's first hover) would cross the first row and fail it. A real pen's own numbers (none here: it was not plugged in on 4 Nov):
# `libinput debug-events` as root, or just this drawing by hand.
#   bash tools/regress/sketch-pen.sh [--keep DIR]   (the shot and the numbers kept in DIR)
# Exit 0 held · 1 broken (what, said) · 2 could not run (no FireAlpaca, no dwl source)
set -u
here=$(cd "$(dirname "$0")" && pwd)
keep=""; [[ ${1:-} == --keep ]] && keep=$2
app=$HOME/.local/share/fedokawaii/firealpaca/app/usr/bin/FireAlpaca
lib=$HOME/.local/lib/fedokawaii/kawa-firealpaca.so
src=$HOME/.local/src/dwl
[[ -x $app && -f $lib ]] || { echo "sketch-pen: FireAlpaca or its skin is not installed" >&2; exit 2; }
[[ -f $src/dwl.c ]] || { echo "sketch-pen: no dwl source at $src" >&2; exit 2; }
w=$(mktemp -d /dev/shm/regress-pen.XXXXXX); trap 'rm -rf "$w"' EXIT
# the private dwl: the tree as it is, a fake tablet added
mkdir "$w/dwl" && tar -C "$src" --exclude=.git --exclude=dwl --exclude='*.o' -cf - . | tar -C "$w/dwl" -xf - || exit 2
python3 -I "$here/../fake-tablet.py" "$w/dwl/dwl.c" >/dev/null || exit 2
# (the mouse parked off the window: a brush with a fade grew a tail on the first stroke until dwl's penmove told
# the window of the pointer once, 4 Nov. A dwl without that line is only tried with the mouse over the window)
park="wlrctl pointer move -8000 -8000; wlrctl pointer move 800 500; sleep 0.3"
grep -q 'also watches the mouse' "$w/dwl/dwl.c" && park="wlrctl pointer move -8000 -8000; sleep 0.3"
inc=$(cat /usr/local/lib/fedokawaii-wlroots-0.20/cflags) l=/usr/local/lib/fedokawaii-wlroots-0.20/lib
make -s -C "$w/dwl" WLR_INCS="$inc" WLR_LIBS="-Wl,-rpath,$l -L$l -lwlroots-0.20 -lpixman-1 -ldrm" \
  XWAYLAND=-DXWAYLAND XLIBS="xcb xcb-icccm pixman-1 glesv2" >"$w/make.log" 2>&1 || { echo "sketch-pen: the private dwl did not build ($(tail -n 1 "$w/make.log"))" >&2; exit 2; }
mkfifo "$w/tablet"
h=$w/home; mkdir -p "$h/.config/fedokawaii" "$h/.local/share/FireAlpaca/FireAlpaca"
cp -a "$HOME/.config/fedokawaii/themes" "$h/.config/fedokawaii/"; ln -s "$(readlink "$HOME/.config/fedokawaii/current")" "$h/.config/fedokawaii/current"
mkdir -p "$h/.local/share/fedokawaii" && ln -s "$HOME/.local/share/fedokawaii/firealpaca" "$h/.local/share/fedokawaii/firealpaca"
cp "$here/../../configs/firealpaca/"* "$h/.local/share/FireAlpaca/FireAlpaca/"       # (the layout the rows below are measured on)
cp "$HOME/.local/share/fedokawaii/firealpaca/blank.mdp" "$w/page.mdp"
cat >"$w/inside.sh" <<PLAY
export HOME=$h XDG_CONFIG_HOME=$h/.config XDG_DATA_HOME=$h/.local/share XDG_CACHE_HOME=$h/.cache XDG_STATE_HOME=$h/.local/state
cd "\$HOME" || exit 1
# (no session bus: it needs none, and the bundle's old libdbus can take 41 s to greet a fenced one, 4 Nov; 1 ms the real one)
( ulimit -c 0; exec env -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=xcb DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent KAWA_FA_OPEN="$w/page.mdp" LD_PRELOAD="$lib" "$app" ) >"$w/app.log" 2>&1 &
sleep 9
$park
pen() { printf '%s\n' "\$*" >"$w/tablet"; sleep 0.012; }
for row in "300 0.10" "500 0.50" "700 1.00"; do
  set -- \$row; y=\$1 p=\$2
  pen i 600 \$y; sleep 0.15; pen m 600 \$y 0; sleep 0.05; pen d
  x=600; while [ \$x -lt 1000 ]; do pen m \$x \$y \$p; x=\$((x+4)); done
  pen u; sleep 0.1; pen o; sleep 0.3
done
sleep 1
grim "$w/shot.png"
PLAY
FAKE_TABLET=$w/tablet bash "$here/../hl-dwl.sh" "$w/inside.sh" --dwl "$w/dwl/dwl" --time 90 --keep "$w/logs" || { echo "sketch-pen: the run failed: $(tail -n 2 "$w/logs/script.log" "$w/logs/dwl.log" 2>/dev/null | cut -c1-200)" >&2; exit 2; }
[[ -s $w/shot.png ]] || { echo "sketch-pen: no shot" >&2; exit 2; }
out=$(python3 -I - "$w/shot.png" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("L")
print(" ".join(str(sum(1 for y in range(row - 30, row + 30) if im.getpixel((800, y)) < 128)) for row in (300, 500, 700)))
PY
) || exit 2
read -r a b c <<<"$out"
[[ -n $keep ]] && { mkdir -p "$keep"; cp "$w/shot.png" "$keep/sketch-pen.png"; echo "$a $b $c" >"$keep/sketch-pen.txt"; }
if ((a > 0 && a < b && b < c && a * 3 <= c)); then
  echo "sketch-pen: held: the stroke is $a, $b and $c px wide at pressure 0.10, 0.50 and 1.00"; exit 0
fi
echo "sketch-pen: pressure does not reach the stroke: $a, $b and $c px at 0.10, 0.50 and 1.00" >&2; exit 1
