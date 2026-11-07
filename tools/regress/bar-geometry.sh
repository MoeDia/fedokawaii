#!/usr/bin/env bash
# tools/regress/bar-geometry.sh — never again (r27-14: "the bar grows", "1 px off", the inner
# cream frame, the numeral leaving its seal; r28 sa25d: the jikusaki bar): the bar rendered headless
# (tools/kit.sh, the real GPU, both themes) and measured against docs/design-system.md §8 to the pixel —
#   · 39 rows: 4 of air, the hairline, 30 of paper, the hairline, 2 of shadow, a row of air
#   · the outer tiles' hairlines on x 8 and x 1911; 4 px hairline to hairline within a group,
#     12 between groups (the shadow's column in the gap)
#   · 10 px from the paper's edge to the ink, both sides, in every tile (the gear's odd pixel on
#     its right); the ink on the line's rows (10–29); the head (a picture) centred on the paper
#   · the workspace you are on: its seal 26 px across, rows 7–32, 5 px of paper either side, its
#     numeral (16 wide) 10 px from the paper either side: the two centred on each other
#   · the clock: a scroll between two rods; the day's kanji on x 960 (its ink's centre within half
#     a pixel), 18 px from the date to the kanji and from the kanji to the time, 10 from the time
#     to the right band, at least 10 from the left band to the date (that side padded)
#   bash tools/regress/bar-geometry.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-bar.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
fail=0
no() { echo "bar-geometry ($th): $*" >&2; fail=1; }
for th in dark light; do
  # (two layouts, as the session has them: the keyboard's tile shown — "us", small: Caps Lock off)
  XKB_DEFAULT_LAYOUT=us,ara XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle \
    bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" bar >"$out/kit-$th.log" 2>&1 \
    || { echo "bar-geometry: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  fibre=$HOME/.config/fedokawaii/themes/$th/kami-fibre.png
  [[ " $* " == *" --repo-art "* ]] && fibre=$here/../../configs/home/.config/fedokawaii/themes/$th/kami-fibre.png
  m=$(python3 -I "$here/shots.py" bar "$out/$th/bar.png" "$fibre") || { echo "bar-geometry: no bar measured" >&2; exit 2; }
  [[ $(grep '^rows ' <<<"$m") == "rows 0+4 4+1 5+30 35+1 36+1 37+1 38+1" ]] || no "rows: $(grep '^rows ' <<<"$m") (want 4 air, hairline, 30 paper, hairline, 2 shadow, air)"
  first=$(grep -m1 '^tile ' <<<"$m"); last=$(grep '^tile ' <<<"$m" | tail -n1); gear=$(grep '^tile ' <<<"$m" | tail -n2 | head -n1)
  [[ $(cut -d' ' -f2 <<<"$first") == 8 ]] || no "the left tile's hairline on x $(cut -d' ' -f2 <<<"$first"), not 8"
  [[ $(cut -d' ' -f3 <<<"$last") == 1912 ]] || no "the right tile's shadow column on x $(cut -d' ' -f3 <<<"$last"), not 1912 (its hairline on 1911)"
  read -ra air < <(sed -n 's/^gaps //p' <<<"$m")
  for g in "${air[@]}"; do
    ((g == 2 || g == 3 || g == 11 || g > 100)) || no "a gap of $g px of air between tiles (3 within a group, 11 between: + the shadow's column; 2 to the clock's rods)"
  done
  while read -r _ a b _ _ _ _ i0 i1 _ r0 r1 _ l _ r rest; do   # (tile A B paper P0 P1 ink I0 I1 rows R0 R1 left L right R)
    [[ $rest == scroll ]] && continue
    if ((b - a == 38 && i1 - i0 == 25)); then     # (a stamp: the seal is its ink)
      ((l == 5 && r == 5 && r0 == 7 && r1 == 32)) || no "the seal at $a: $l/$r px from the paper, rows $r0–$r1"
      read -r _ _ _ _ nl _ nr < <(grep -A1 "^tile $a $b " <<<"$m" | grep '^numeral ')
      [[ ${nl:-} == 10 && ${nr:-} == 10 ]] || no "the seal's numeral at $a: ${nl:-?}/${nr:-?} px from the paper (want 10, 10)"
      continue
    fi
    if [[ "tile $a $b " == "$(cut -d' ' -f1-3 <<<"$last") " ]]; then   # (the head: a picture, its own art: on the paper's rows, centred — its odd pixel of air at the right)
      ((r0 >= 5 && r1 <= 34 && (r == l || r == l + 1))) || no "the head at $a: $l/$r px from the paper, rows $r0–$r1 (want centred)"
      continue
    fi
    if [[ "tile $a $b " == "$(cut -d' ' -f1-3 <<<"$gear") " ]]; then   # (the gear: 16 columns, 10 to the left, the odd pixel to the right)
      ((l == 10 && (r == 10 || r == 11))) || no "the gear at $a: $l/$r px from the paper (want 10, 10 or 11)"
    else
      ((l == 10 && r == 10)) || no "the tile at $a: $l px paper→ink, $r px ink→paper (want 10, 10)"
    fi
    ((r0 >= 10 && r1 <= 29)) || no "the tile at $a: ink on rows $r0–$r1 (outside the line's 10–29)"
  done < <(grep '^tile ' <<<"$m")
  sc=$(grep ' scroll$' <<<"$m") || { no "no clock"; continue; }
  read -r _ _ _ _ _ _ _ _ _ _ _ _ _ sl _ sr _ <<<"$sc"
  ((sl >= 10)) || no "the left band → the date: $sl px, under 10"
  ((sr == 10)) || no "the time → the right band: $sr px, not 10"
  read -ra parts < <(grep '^clock ' <<<"$m" | sed 's/^clock //; s/ gaps.*//')
  k=-1
  for i in "${!parts[@]}"; do p0=${parts[i]%-*}; p1=${parts[i]#*-}; ((p0 <= 960 && p1 >= 959)) && k=$i; done
  if ((k < 1 || k + 1 >= ${#parts[@]})); then no "no kanji on x 960 between the date and the time: ${parts[*]}"; continue; fi
  p0=${parts[k]%-*}; p1=${parts[k]#*-}
  ((p0 + p1 >= 1918 && p0 + p1 <= 1920)) || no "the kanji's ink $p0–$p1: its centre not on x 960 (×2: $((p0 + p1)), want 1919 ± 1)"
  dk=$((p0 - ${parts[k - 1]#*-} - 1)) kt=$((${parts[k + 1]%-*} - p1 - 1))
  ((dk == 18 && kt == 18)) || no "the clock's gaps: $dk date→kanji, $kt kanji→time (want 18, 18)"
done
((fail)) && exit 1
echo "bar-geometry: held — 39 rows, hairlines on x 8 and 1911, gaps 4/12, 10 px to the ink in every tile, the seal round its numeral, the kanji on 960, the clock 18·18·10, both themes"
