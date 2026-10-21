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
