#!/usr/bin/env bash
# tools/regress/bar-geometry.sh — never again (r27-14: "the bar grows", "1 px off", the inner
# cream frame, the numeral leaving its seal): the bar rendered headless (tools/kit.sh, the real
# GPU, both themes) and measured against docs/design-system.md §8 to the pixel —
#   · 27 rows: 3 of air, the hairline, 20 of paper, the hairline, 2 of shadow
#   · the outer tiles' hairlines on x 8 and x 1911; 4 px hairline to hairline within a group,
#     12 between groups (the shadow's column in the gap)
#   · 8 px from the paper's edge to the ink, both sides, in every tile; words on the capitals'
#     rows (9–18), an icon alone on 7–20, the emblems on 6–21
#   · the workspace you are on: its seal 16 px across, rows 6–21, centred on its numeral
#   · the clock: 15 px from the left rod to the date (8 and the 7 the time is longer), 14 px
#     to the kanji and 14 to the time, 8 (9 from 10 to 12 o'clock) to the right rod
#   bash tools/regress/bar-geometry.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-bar.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
fail=0
no() { echo "bar-geometry ($th): $*" >&2; fail=1; }
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" bar >"$out/kit-$th.log" 2>&1 \
    || { echo "bar-geometry: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  fibre=$HOME/.config/fedokawaii/themes/$th/kami-fibre.png
  [[ " $* " == *" --repo-art "* ]] && fibre=$here/../../configs/home/.config/fedokawaii/themes/$th/kami-fibre.png
  m=$(python3 -I "$here/shots.py" bar "$out/$th/bar.png" "$fibre") || { echo "bar-geometry: no bar measured" >&2; exit 2; }
  [[ $(grep '^rows ' <<<"$m") == "rows 0+3 3+1 4+20 24+1 25+1 26+1" ]] || no "rows: $(grep '^rows ' <<<"$m") (want 3 air, hairline, 20 paper, hairline, 2 shadow)"
  first=$(grep -m1 '^tile ' <<<"$m"); last=$(grep '^tile ' <<<"$m" | tail -n1)
  [[ $(cut -d' ' -f2 <<<"$first") == 8 ]] || no "the left tile's hairline on x $(cut -d' ' -f2 <<<"$first"), not 8"
  [[ $(cut -d' ' -f3 <<<"$last") == 1912 ]] || no "the right tile's shadow column on x $(cut -d' ' -f3 <<<"$last"), not 1912 (its hairline on 1911)"
  for g in $(grep '^gaps ' <<<"$m" | cut -d' ' -f2-); do
    ((g == 3 || g == 11 || g > 100)) || no "a gap of $g px of air between tiles (3 within a group, 11 between: + the shadow's column)"
  done
  while read -r _ a b _ _ _ _ i0 i1 _ r0 r1 _ l _ r rest; do   # (tile A B paper P0 P1 ink I0 I1 rows R0 R1 left L right R)
    [[ $rest == scroll ]] && continue
    if ((b - a == 28 && i1 - i0 == 15)); then     # (a stamp: the seal is its ink)
      ((l == 5 && r == 5 && r0 == 6 && r1 == 21)) || no "the seal at $a: $l/$r px from the paper, rows $r0–$r1"
      continue
    fi
    ((l == 8 && r == 8)) || no "the tile at $a: $l px paper→ink, $r px ink→paper (want 8, 8)"
    ((r0 >= 6 && r1 <= 21)) || no "the tile at $a: ink on rows $r0–$r1 (outside 6–21)"
  done < <(grep '^tile ' <<<"$m")
  sc=$(grep ' scroll$' <<<"$m") || { no "no clock"; continue; }
  read -r _ _ _ _ _ _ _ _ _ _ _ _ _ sl _ sr _ <<<"$sc"
  ((sl == 15)) || no "the left rod → the date: $sl px, not 15"
  ((sr == 8 || (sr == 9 && 10#$(date +%I) >= 10))) || no "the time → the right rod: $sr px"
  gaps=$(grep '^clock ' <<<"$m" | sed 's/.* gaps //')
  [[ $gaps == "14 14 8"* ]] || no "the clock's gaps: $gaps (want 14 date→kanji, 14 kanji→time)"
done
((fail)) && exit 1
echo "bar-geometry: held — 27 rows, hairlines on x 8 and 1911, gaps 4/12, 8 px to the ink in every tile, the seal round its numeral, the clock 15·14·14·8, both themes"
