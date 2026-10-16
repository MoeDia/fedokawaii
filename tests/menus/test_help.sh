#!/usr/bin/env bash
# tests/menus/test_help.sh — kawa-help (Super+/): the keybinding sheet from
# ~/.config/fedokawaii/keybinds.txt as a searchable menu. Every row of the real sheet must fit
# the menu; a missing sheet is said, not shown empty.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() { menus_sandbox; config .config/fedokawaii/keybinds.txt; K=$HOME/.config/fedokawaii/keybinds.txt; }

case_ "the sheet: every line but the blank ones, a filter prompt, 68 wide, 24 lines, the first binding selected"
setup; answer esc; rc 0 kawa-help
eq "$(fz_rows)" "$(grep -v '^[[:space:]]*$' "$K")"
eq "$(fz_arg prompt)" "> "; eq "$(fz_arg width)" 68; eq "$(fz_arg lines)" 24; eq "$(fz_arg select-index)" 1
eq "$(fz_rows | sed -n 2p | cut -d' ' -f1)" "Super+Return" "row 1 is a binding, not a heading"
eq "$(fz_arg anchor)" "" "centred"
case_ "every row of the real sheet fits the menu (67 columns; the icon in the bar counts two)"
fits
case_ "the headings' rules all end in the same column"
eq "$(grep '^── ' "$K" | python3 -I "$MD/cols.py" | sort -u | tr '\n' ' ')" "67 "
case_ "each binding's description starts in the same column (24)"
bad=$(python3 -I -c '
import sys
for l in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if l.strip() and not l.startswith("── ") and not (l[23:24] == " " and l[24:25] not in ("", " ")):
        print(l)' "$K")
eq "$bad" "" "lines whose description is out of line"

case_ "Enter on a row, Esc, typed text that matches nothing: the sheet just closes (exit 0)"
for a in enter esc lost "typed zzz"; do setup; answer "$a"; out=$(kawa-help); rc 0 true; eq "$out" ""; done
setup; answer "typed zzz"; rc 0 kawa-help

case_ "the sheet missing (theme not run yet): a notice says so, no empty menu, exit 1"
setup; rm "$K"; rc 1 kawa-help
called 'notify-send -a desktop Help keybinds.txt missing — run the theme'
eq "$(fz_n)" 0
case_ "a sheet with blank lines (edited in the copy): they are left out, not shown as empty rows"
setup; printf 'Super+A                 one\n\n   \nSuper+B                 two\n\t\n' >"$K"; answer esc; kawa-help
eq "$(fz_rows)" $'Super+A                 one\nSuper+B                 two'
case_ "an empty sheet: an empty menu, no error"
setup; : >"$K"; answer esc; rc 0 kawa-help

case_ "a home folder with a space in its name: the sheet still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$HOME/.config/fedokawaii/keybinds.txt")"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-help --help)" "every keybinding"; rc 0 kawa-help --help
rc 2 kawa-help extra; eq "$(fz_n)" 0

done_
