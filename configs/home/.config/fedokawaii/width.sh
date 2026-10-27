# ~/.config/fedokawaii/width.sh — the menus' width helpers (sourced: kawa-drives, kawa-share,
# kawa-file, kawa-hush).
# shellcheck shell=bash
# cols TEXT — how many columns TEXT takes in a menu: what a terminal counts (wc -L: a kanji or
# kana two, every other letter one). The desktop's faces draw exactly that (Sumi UI: an 8 px
# column a letter, 16 a wide one; Sumi Term: 10 and 20 — tools/build-fonts.py)
cols() {
  LC_ALL=C.UTF-8 wc -L <<<"$1"
}
# cut_cols TEXT N — TEXT in at most N columns: what does not fit goes, at a word's end where
# one is (a single word too long loses its last letters) — never an "…", never a space at its
# end (counted in letters, whatever the locale)
cut_cols() {
  local LC_ALL=C.UTF-8 t=$1 n=$2 w
  (( $(cols "$t") <= n )) && { printf '%s' "$t"; return; }
  t=${t:0:n}
  while (( $(cols "$t") > n )); do t=${t%?}; done
  [[ ${1:${#t}:1} != ' ' && $t == *' '* ]] && { w=${t% *}; [[ -n ${w//[ ]/} ]] && t=$w; }
  printf '%s' "${t%"${t##*[! ]}"}"
}
# air TEXT → __air: "lN rM", the bar's classes for TEXT on a tile — the empty columns of Sumi
# UI before its first letter's ink (N) and after its last's (M), 0–3 px, so style.css
# pads each tile to exactly 8 px of paper to the ink at both ends, whatever the words. From
# the face itself (tools/build-fonts.py measures it and checks these against it); a letter
# past ASCII (a kanji, an icon): 0
__AIR_L=3210003211121200100000000221010000000000200000000001001010201002000000002102100000000110002310
__AIR_R=3211113121131311111111111331111111111111221111111111111111112112111111113213111111111111111321
air() {
  local a=${1:0:1} z=${1: -1} i j l=0 r=0
  printf -v i '%d' "'${a:- }"; printf -v j '%d' "'${z:- }"
  ((i > 32 && i < 127)) && l=${__AIR_L:i-33:1}
  ((j > 32 && j < 127)) && r=${__AIR_R:j-33:1}
  __air="l$l r$r"
}
