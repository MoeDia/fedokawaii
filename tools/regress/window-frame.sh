#!/usr/bin/env bash
# tools/regress/window-frame.sh — never again (r27-15, "window borders get the bar's 3D shadow
# look"; the 1 px off gaps): two tiled windows in a headless dwl (tools/kit.sh, the real GPU,
# both themes), their frames measured against docs/design-system.md §4 and §12 —
#   · a 1 px hairline: the focused window's vermilion, the other's the hairline's ink; its
#     corner pixels left out
#   · the shadow outside it: the column right of the right hairline down to the bottom
#     hairline's row, the first row under it to under the right hairline, the second a pixel
#     further right — and nothing under the column on the first row
#   · the edges: x 8 and x 1911 (the bar's outer hairlines), 8 px between the windows' hairlines
#   bash tools/regress/window-frame.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-frame.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
nap 0.8
foot -e sleep 30 >/dev/null 2>&1 &
nap 1.2
foot -e sleep 30 >/dev/null 2>&1 &
nap 1.5
at 1400 600
nap 0.6
shot frames
PLAY
fail=0
no() { echo "window-frame ($th): $*" >&2; fail=1; }
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "window-frame: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  m=$(python3 -I "$here/shots.py" frames "$out/$th/frames.png" 500) || { echo "window-frame: nothing measured" >&2; exit 2; }
  read -r -a ch <<<"$(sed -n 's/^changes //p' <<<"$m")"
  ((${#ch[@]} == 10)) || { no "row 500: ${#ch[@]} changes, not 10 (two frames, two shadow columns): ${ch[*]}"; continue; }
  x() { echo "${ch[$1]%%:*}"; }; c() { echo "${ch[$1]#*:}"; }
  (($(x 0) == 8)) || no "the left window's left hairline on x $(x 0), not 8"
  (($(x 7) == 1911 && $(x 8) == 1912)) || no "the right window's right hairline on x $(x 7), its shadow column on $(x 8)"
  (($(x 5) - $(x 2) - 1 == 8)) || no "$(($(x 5) - $(x 2) - 1)) px between the windows' hairlines, not 8"
  [[ $(c 2) == "$(c 0)" && $(c 5) == "$(c 7)" && $(c 0) != "$(c 5)" ]] || no "one ink a frame, the two frames apart: $(c 0) $(c 2) / $(c 5) $(c 7)"
  [[ $(c 3) == "$(c 8)" ]] || no "the two shadow columns differ: $(c 3) $(c 8)"
  mapfile -t k < <(sed -n '/^corner at/,$p' <<<"$m" | tail -n 4)
  ((${#k[@]} == 4)) || { no "no corner map"; continue; }
  L0=${k[0]} L1=${k[1]} L2=${k[2]} L3=${k[3]}
  [[ ${L1:4:1} != "${L1:3:1}" ]] || no "the bottom-right corner pixel is not left out: $L1"
  [[ ${L1:5:1} == "${L0:5:1}" ]] || no "the shadow column stops before the bottom hairline's row: $L0 / $L1"
  [[ ${L2:0:5} == "${L2:0:1}${L2:0:1}${L2:0:1}${L2:0:1}${L2:0:1}" && ${L2:0:1} != "${L1:0:1}" ]] || no "the shadow's first row is not one ink from a pixel in to under the hairline: $L2"
  [[ ${L2:5:1} == "${L2:6:1}" ]] || no "something under the shadow column on the first row: $L2"
  [[ ${L3:0:6} == "${L0:5:1}${L0:5:1}${L0:5:1}${L0:5:1}${L0:5:1}${L0:5:1}" ]] || no "the second row is not the column's ink, a pixel further right: $L3"
done
((fail)) && exit 1
echo "window-frame: held — hairlines with their corners left out, the shadow's column and two rows as §4 has them, x 8 / 1911, 8 px between windows, both themes"
