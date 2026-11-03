#!/usr/bin/env bash
# tools/regress/tile-widths.sh — never again a prompt tested at widths the desktop does not give
# (the master's T24 review 2: tests/content/test_tiles.sh's WIDTHS were copied by hand and went
# stale when the cell went 10 → 8 px): foot's columns in every tile dwl lays out for 1–8 windows,
# in the spiral and in columns, and at the narrowest Super+H/L reach (mfact's ends, two and three
# windows) — measured in a headless kit with the bar up, then held against test_tiles' WIDTHS.
#   bash tools/regress/tile-widths.sh [KIT OPTION…]
# Exit 0 held (the widths printed) · 1 test_tiles' WIDTHS differ (both said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-widths.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/play.sh" <<'PLAY'
d=$KIT_OUT/sz; mkdir -p "$d"
# (each terminal writes its size five times a second: a later window resizes the earlier ones)
open() { foot sh -c 'while :; do stty size >"$0.t" 2>/dev/null && mv "$0.t" "$0"; sleep 0.2; done' "$d/$1" >/dev/null 2>&1 & }
# measure NAME N — once the N terminals named so have each written a size (5 s at most), then a
# moment for the last retile to reach them: their widths
measure() {
  local f i
  for ((i = 0; i < 50; i++)); do (($(ls "$d/$1"* 2>/dev/null | grep -cv '\.t$') >= $2)) && break; nap 0.1; done
  nap 0.6
  for f in "$d/$1"*; do [[ $f == *.t ]] || say "$1 $(cut -d' ' -f2 "$f")"; done
}
for n in 1 2 3 4 5 6 7 8; do open "spiral$n"; measure spiral "$n"; done
chord logo 2; nap 0.4; chord logo t; nap 0.4
for n in 1 2 3 4 5 6 7 8; do open "tile$n"; measure tile "$n"; done
chord logo 3; nap 0.4; chord logo s; nap 0.4      # (the layout is the screen's: the spiral again)
for w in 3 4; do                                  # (two windows, then three: mfact to each end)
  chord logo "$w"; nap 0.4
  for n in $(seq $((w - 1))); do open "ends$w-$n"; nap 0.4; done
  for _ in $(seq 12); do chord logo h; done; measure "ends$w" $((w - 1))
  for _ in $(seq 18); do chord logo l; done; measure "ends$w" $((w - 1))
done
PLAY
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" --time 200 play >"$out/kit.log" 2>&1 || { echo "tile-widths: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
got=$(awk '{print $2}' "$out/play.log" | sort -rnu | tr '\n' ' ') got=${got% }
[[ $got =~ ^235\  ]] || { echo "tile-widths: no full-screen terminal measured ($got)" >&2; exit 2; }
want=$(sed -n 's/^WIDTHS="\(.*\)"$/\1/p' "$here/../../tests/content/test_tiles.sh")
[[ $got == "$want" ]] || { echo "tile-widths: dwl tiles foot to $got columns; test_tiles' WIDTHS are $want" >&2; exit 1; }
echo "tile-widths: held — dwl tiles foot to $got columns, test_tiles' WIDTHS"
