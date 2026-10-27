# ~/.config/fedokawaii/screen.sh — the grammar of every text screen (fzf in a foot window: the
# system menu, the change menu, the keybinding sheet, the clipboard, books, the share picker,
# Syncplay's form, the job windows, `fedokawaii status`). docs/design-system.md §7: the
# panels' parts in characters.
# shellcheck shell=bash disable=SC2034
#
#   󾂁  system ──────────────────────────────    a heading: its icon (the accent's ink), two
#    󾀼  verify                       passed    columns, the name (strong), a space, the rule
#    󾀜  update                   in 44 days    (edge2) to the edge — solid, never dashed
#                                              a row: a column in, its icon, two columns, the
#                                              name (text); its value right-aligned (muted)
#
# The inks are foot's palette past the sixteen (tools/build-themes.py writes them for both
# themes), so a screen follows a theme switch as every other line in the terminal does; the
# words themselves are the terminal's own foreground (text).
INK_KANJI=$'\e[38;5;20m'     # accent_text: a heading's icon; a value that needs you ("due")
INK_ACCENT=$'\e[38;5;16m'    # accent: the line under the tab shown (Super+U)
INK_MUTED=$'\e[38;5;21m'     # muted: a value, a glyph at rest, a key's name, the footer
INK_FAINT=$'\e[38;5;22m'     # faint: what is not there yet ("none"); the footer's dots
INK_STRONG=$'\e[38;5;23m'    # strong: emphasis
INK_STITCH=$'\e[38;5;19m'    # edge2: a heading's rule
INK_OFF=$'\e[0m'             # back to the words' own ink (text)
STITCH='─'                   # (foot draws the box-drawing letters itself: one pixel, on the line's row 10)

# screen_cols TEXT — the columns TEXT takes in the terminal (a kanji two, an escape none)
screen_cols() {
  local t=$1
  while [[ $t =~ $'\e'\[[0-9\;]*m ]]; do t=${t//"${BASH_REMATCH[0]}"/}; done
  LC_ALL=C.UTF-8 wc -L <<<"$t"
}
# screen_heading ICON NAME W — a part's heading, W columns wide (the rule runs to the last;
# at least two columns of it, whatever the name)
screen_heading() {
  local n s
  n=$(( $3 - $(screen_cols "$1") - 3 - $(screen_cols "$2") )); ((n < 2)) && n=2
  printf -v s '%*s' "$n" ''
  printf '%s%s%s  %s%s%s %s%s%s' "$INK_KANJI" "$1" "$INK_OFF" "$INK_STRONG" "$2" "$INK_OFF" "$INK_STITCH" "${s// /$STITCH}" "$INK_OFF"
}
# screen_row GLYPH NAME VALUE W — a row, W columns wide: VALUE right-aligned at the last
# column, in muted unless it carries an ink of its own (a value that needs you: INK_KANJI)
screen_row() {
  local v=$3 pad=0
  [[ -n $v && $v != $'\e'* ]] && v=$INK_MUTED$v$INK_OFF
  # (no value: nothing to align — and no columns to count, for a long list's sake)
  [[ -n $v ]] && { pad=$(( $4 - 4 - $(screen_cols "$2") - $(screen_cols "$v") )); ((pad < 2)) && pad=2; }
  printf ' %s%s%s  %s%*s%s' "$INK_MUTED" "$1" "$INK_OFF" "$2" "$pad" '' "$v"
}
# screen_footer KEY… — the footer's words: "enter run" "esc close" → enter run  ·  esc close
# (fzf draws it in muted itself, --color footer; elsewhere: printf '%s%s' "$INK_MUTED" …)
screen_footer() {
  local out="" w
  for w; do out+=${out:+"  $INK_FAINT·$INK_MUTED  "}$w; done
  printf '%s' "$out"
}
# screen_width — the width a screen's lines have: the terminal's, less two columns of paper each
# side (in fzf: its margin of one and its pointer's column; outside fzf, two spaces). Fails
# without a terminal: a screen is drawn only in one
screen_width() {
  local c
  c=$(stty size 2>/dev/null </dev/tty) && c=${c#* } && [[ $c =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' $((c - 4))
}
