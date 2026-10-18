#!/usr/bin/env bash
# tests/menus/test_help.sh — kawa-help (Super+/): the keybinding sheet from
# ~/.config/fedokawaii/keybinds.txt as a searchable menu. Every row of the real sheet must fit
# the menu; a missing sheet is said, not shown empty.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() { menus_sandbox; config .config/fedokawaii/keybinds.txt; K=$HOME/.config/fedokawaii/keybinds.txt; }
GAP=$(. "$REPO/configs/home/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_GAP")
IN="    $GAP"                                        # a row's start: in by an icon and its two spaces

case_ "the sheet: every line but the blank ones, a filter prompt, 73 wide, 24 lines, the first binding selected"
setup; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$K")"
eq "$(fz_arg prompt)" "> "; eq "$(fz_arg width)" 73; eq "$(fz_arg lines)" 24; eq "$(fz_arg select-index)" 1
eq "$(fz_rows | sed -n 2p | sed "s/^$IN//" | cut -d' ' -f1)" "Super+Return" "row 1 is a binding, not a heading"
eq "$(fz_arg anchor)" "" "centred"
case_ "every row of the real sheet fits the menu (the font's ─ … → are two columns, the icons 14 px)"
fits
case_ "set for the menu's font: parts headed as Super+U's (kanji, name, a rule to the edge), a gap above each but the first, a space fewer after each wide … or → in the keys"
eq "$(fz_rows | grep -c '─')" 0 "no ─ left"
heads=$(fz_rows | grep -- '–$')
eq "$(python3 -I "$MD/cols.py" --px <<<"$heads" | sort -u | tr '\n' ' ')" "428 " "every heading's rule ends on the last pixel the menu shows whole (73 × 6 − 10)"
eq "$(python3 -I -c 'import sys; print("".join(l[0] for l in sys.stdin.read().splitlines()))' <<<"$heads")" "起写窓場音端書盤席筆" "each part's kanji, by its name"
eq "$(fz_rows | grep -c '^$')" "$(( $(wc -l <<<"$heads") - 1 ))" "an empty row above every heading but the first"
eq "$(fz_rows | head -n1 | grep -c -- '–$')" 1 "the sheet starts with its first heading"
has "$(fz_rows)" "Super+1…9              go to workspace"
bad=$(fz_rows | grep -v -- '–$' | grep -v '^$' | python3 -I -c '
import sys
sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[1]); from cols import px
for l in sys.stdin.read().splitlines():
    i = 29                                       # the description: the first word to start
    while i > 1 and not (l[i] != " " and l[i - 1] == " "): i -= 1   # at or before column 29
    if sum(px(c) for c in l[:i]) != 144 + 26: print(l)' "$MD")
eq "$bad" "" "rows whose description is out of line in the menu"
eq "$(fz_rows | grep -v -- '–$' | grep -v '^$' | grep -vc "^$IN")" 0 "every binding starts at the text column (an icon and two spaces in, under its part's name)"
case_ "the sheet itself (a terminal's columns): the rules end in column 67, each description at 24"
eq "$(grep '^── ' "$K" | python3 -I -c 'import sys; print(*sorted({len(l) for l in sys.stdin.read().splitlines()}))')" "67"
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
called 'notify-send -a desktop help keybinds.txt is missing — fedokawaii repair puts it back'
eq "$(fz_n)" 0
case_ "a sheet with blank lines (edited in the copy): they are left out, not shown as empty rows"
setup; printf 'Super+A                 one\n\n   \nSuper+B                 two\n\t\n' >"$K"; answer esc; kawa-help
eq "$(fz_rows)" "$IN"$'Super+A                 one\n'"$IN"$'Super+B                 two'
case_ "an empty sheet: an empty menu, no error"
setup; : >"$K"; answer esc; rc 0 kawa-help

case_ "a home folder with a space in its name: the sheet still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$HOME/.config/fedokawaii/keybinds.txt")"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-help --help)" "every keybinding"; rc 0 kawa-help --help
rc 2 kawa-help extra; eq "$(fz_n)" 0

done_
