#!/usr/bin/env bash
# tests/menus/test_help.sh — kawa-help (Super+/): the keybinding sheet from
# ~/.config/fedokawaii/keybinds.txt as a searchable menu in the panel's line format (parts under
# their kanji, an info row a binding: only read, nothing chosen); a missing sheet is said, not shown empty.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() { menus_sandbox; config .config/fedokawaii/keybinds.txt; K=$HOME/.config/fedokawaii/keybinds.txt; }
# what the sheet's rows are, by the sheet's own rule: the key (to its gap of 2+ spaces ending
# at column 24 or later; with none, to the first word at or after 24) and its description —
# printed as the menu's lines should be
LINES='
import re, sys
for l in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if not l.strip(): continue
    if l.startswith("─"): continue
    gaps = [m.end() for m in re.finditer(r"  +", l) if m.end() >= 24]
    i = gaps[0] if gaps else 24
    while not gaps and i < len(l) and not (l[i] != " " and l[i - 1] == " "): i += 1
    print("info\t\t" + l[:i].strip() + "\t" + l[i:].strip())'

case_ "the sheet: every line but the blank ones, a filter prompt, sized to its content, 24 lines, no cursor (info rows are only read)"
setup; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$K")"
eq "$(fz_arg prompt)" "> "; eq "$(fz_arg width)" ""; eq "$(fz_arg lines)" 24; eq "$(fz_arg select)" ""
eq "$(fz_rows | sed -n 2p)" "info		Super+Return	terminal (foot)" "line 1 is a binding, not a heading"
eq "$(fz_arg drop)" "" "centred"; fits
case_ "every binding an info row: no glyph, the key as its name, what it does as its detail (the panel's column), as the sheet says"
eq "$(fz_rows | grep '^info')" "$(python3 -I -c "$LINES" "$K")"
has "$(fz_rows)" "info		Super+1…9	"
case_ "every part under its kanji and name: what follows a colon or is in brackets at the heading's end"
eq "$(fz_rows | grep -vc -e '^part	' -e '^info	')" 0 "nothing but parts and info rows (the panel spaces its parts)"
eq "$(fz_rows | head -n1)" "part	起	launch	" "the sheet starts with its first heading"
has "$(fz_rows)" "part	写	screenshots	clipboard + ~/Pictures/Screenshots"
has "$(fz_rows)" "part	盤	drives	USB sticks, disks, SD cards"
has "$(fz_rows)" "part	音	sound, music, monitor	"
eq "$(fz_rows | grep -c '^part')" "$(grep -c '^─' "$K")"
case_ "a part of your own: 節"
setup; printf '%s\n' '── my keys ──' 'Super+F12               mine' >"$K"; answer esc; kawa-help
eq "$(fz_rows | head -n1)" "part	節	my keys	"

case_ "a key longer than the sheet's column (Super+drag / right-drag, and longer): split at its own gap"
setup
printf '%s\n' '── windows ──' 'Super+Q                 close' 'Super+drag / right-drag move / resize' \
  'Super+Shift+Ctrl+drag / right-drag  swap and resize' 'Super+→ or End          wide arrow' >"$K"
answer esc; rc 0 kawa-help
has "$(fz_rows)" "info		Super+drag / right-drag	move / resize"
has "$(fz_rows)" "info		Super+Shift+Ctrl+drag / right-drag	swap and resize"
has "$(fz_rows)" "info		Super+→ or End	wide arrow"; fits

case_ "the sheet itself (a terminal's columns): the rules end in column 67, each description at 24"
setup
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
called 'notify-send -a desktop -u critical -- .*  keybindings keybinds.txt is missing — fedokawaii repair puts it back'
eq "$(fz_n)" 0
case_ "a sheet with blank lines (edited in the copy): they are left out, not shown as empty rows"
setup; printf 'Super+A                 one\n\n   \nSuper+B                 two\n\t\n' >"$K"; answer esc; kawa-help
eq "$(fz_rows)" $'info\t\tSuper+A\tone\ninfo\t\tSuper+B\ttwo'
case_ "an empty sheet: an empty menu, no error"
setup; : >"$K"; answer esc; rc 0 kawa-help

case_ "a home folder with a space in its name: the sheet still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$HOME/.config/fedokawaii/keybinds.txt")"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-help --help)" "every keybinding"; rc 0 kawa-help --help
rc 2 kawa-help extra; eq "$(fz_n)" 0

done_
