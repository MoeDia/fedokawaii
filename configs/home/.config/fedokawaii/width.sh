# ~/.config/fedokawaii/width.sh — made by tools/build-width.py from art/fusion-wide.txt; do not edit.
# shellcheck shell=bash disable=SC2034
# cols TEXT — how many columns TEXT takes in a menu (fuzzel, in Fusion Pixel): what a
# terminal counts (wc -L: a Japanese letter two), and one more for each letter below U+3000
# that the font draws two columns wide (─ … → — © and the like), which a terminal counts as one.
FUSION_WIDE='[©®¼-¾‐—-‗†-‧‰-‱※⁃℃℉№™Ω-℧K-Å℮⅐-↋←-⇿⌌-⌟⏎-⏏⏨-⏿①-☔☖-☡☤-☥☨-♯⚀-⚕⚘-⚚⚪-⚬⚲-⚵⚸⚼⚿⛄-⛌⛎-⛏⛒-⛔⛘-⛞⛠-⛯⛱-⛳⛵-⛶⛸⛼-⛽⛿✈-✉❦-❧❶-➓⺀-⺙⺛-⻳⼀-⿕⿰-⿿]'
cols() {
  local LC_ALL=C.UTF-8 t=$1 n
  n=${t//$FUSION_WIDE/}
  printf '%s\n' $(( $(LC_ALL=C.UTF-8 wc -L <<<"$t") + ${#t} - ${#n} ))
}
# cut_cols TEXT N — TEXT in at most N columns; cut, it ends in "…" (two columns in the font),
# never mid-letter and with no space before the "…" (counted in letters, whatever the locale)
cut_cols() {
  local LC_ALL=C.UTF-8 t=$1 n=$2
  (( $(cols "$t") <= n )) && { printf '%s' "$t"; return; }
  t=${t:0:n-2}
  while (( $(cols "$t") > n - 2 )); do t=${t%?}; done
  printf '%s…' "${t%"${t##*[! ]}"}"
}
# heading KANJI NAME W — a part's heading in a menu W columns wide, as Super+U heads its
# parts: the kanji (12 px) over the icons, then ICON_GAP (icons.sh: 2 px) and two spaces, so
# the name starts where the entries' names do (an icon is 14 px), then a rule of en dashes
# (6 px each) to the last pixel the menu shows whole (W × 6 − 10)
heading() {
  local LC_ALL=C.UTF-8 h="$1${ICON_GAP:-}  $2 " i n
  n=$(( $3 - 7 - $(cols "$2") ))
  for ((i = 0; i < n; i++)); do h+='–'; done
  printf '%s' "$h"
}
