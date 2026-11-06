#!/usr/bin/env bash
# tools/regress/glass-cells.sh — never again black areas around the text (bug 2, r27-21-bug2: "the notes while typing
# you can see black areas", cells naming the ground's colour drawn opaque under a see-through terminal): each
# program in a real foot over a white wallpaper, in the see-through ground as the desktop has it: not one
# cell of the program's may show the theme's ground opaque — everything the ground's colour is the glass.
#   bash tools/regress/glass-cells.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-glass.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY_END'
panel; nap 0.5
mkdir -p "$HOME/dojo/demo"; (cd "$HOME/dojo/demo" && git init -q && echo x >a && git add a && git -c user.name=t -c user.email=t@t commit -qm first)
printf 'a line of notes\nand another\n' >"$HOME/page.md"
pkill -x -P "$PPID" swaybg 2>/dev/null
swaybg -c '#ffffff' >/dev/null 2>&1 &
nap 1
run() {   # run NAME CMD… — a window with it, its picture
  local n=$1; shift
  foot -a float -T glass -W 100x30 "$@" >/dev/null 2>&1 & w=$!
  nap 2.2; shot "$n"; kill "$w" 2>/dev/null; wait "$w" 2>/dev/null; nap 0.3
}
run notes  kawa-notes --inside
run nvim   nvim "$HOME/page.md"
run yazi   yazi "$HOME"
run git    kawa-git
run clip   kawa-clip --tui
run lazygit sh -c "cd $HOME/dojo/demo && exec lazygit"
run btop   btop
run prompt bash -i
PLAY_END
fail=0
for th in dark light; do
  ground=$(sed -n 's/^C_GROUND=//p' "$HOME/.config/fedokawaii/themes/$th/colors.sh" | tr -d '"'\''')
  [[ " $* " == *" --repo-art "* ]] && ground=$(sed -n 's/^C_GROUND=//p' "$here/../../configs/home/.config/fedokawaii/themes/$th/colors.sh" | tr -d '"'\''')
  [[ $ground =~ ^[0-9a-fA-F]{6}$ ]] || { echo "glass-cells: no ground in the $th theme" >&2; exit 2; }
  bash "$here/../kit.sh" --theme "$th" "$@" --time 60 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "glass-cells: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  python3 -I - "$out/$th" "$ground" "$th" <<'PY_END' || fail=1
import glob, os, sys
import numpy as np
from PIL import Image
d, ground, th = sys.argv[1:4]
g = tuple(bytes.fromhex(ground))
bad = []
for f in sorted(glob.glob(os.path.join(d, "*.png"))):
    a = np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)
    # the window: what is not the white wallpaper under the bar
    w = np.any(a[40:] != 255, axis=-1)
    ys, xs = np.nonzero(w)
    if not len(ys):
        bad.append(f"{os.path.basename(f)[:-4]}: no window")
        continue
    box = a[40 + ys.min():40 + ys.max() + 1, xs.min():xs.max() + 1]
    # (an area, not ink: letters may be drawn in the ground's colour on a lit row, a cell's whole
    # width and half its height of it is what he saw)
    m = np.all(box == g, axis=-1).astype(np.int32)
    i = np.zeros((m.shape[0] + 1, m.shape[1] + 1), dtype=np.int32)
    i[1:, 1:] = m.cumsum(0).cumsum(1)
    h, w_ = 10, 8
    full = i[h:, w_:] - i[:-h, w_:] - i[h:, :-w_] + i[:-h, :-w_] == h * w_
    n = int(full.sum())
    if n:
        ys, xs = np.nonzero(full)
        bad.append(f"{os.path.basename(f)[:-4]}: an area of the opaque ground at x {xs.min()}, y {ys.min()} of the window")
for b in bad:
    print(f"glass-cells ({th}): {b}")
sys.exit(1 if bad else 0)
PY_END
done
((fail)) && exit 1
echo "glass-cells: held — notes, neovim, yazi, the repositories, the clipboard, lazygit, btop and the prompt: no cell of the opaque ground, both themes"
