#!/usr/bin/env bash
# tests/menus/test_help.sh — kawa-help (Super+/): the keybinding sheet from
# ~/.config/fedokawaii/keybinds.txt as a searchable menu in the panel's line format (parts under
# their icons, an info row a binding: only read, nothing chosen); a missing sheet is said, not shown empty.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() { menus_sandbox; config .config/fedokawaii/keybinds.txt; K=$HOME/.config/fedokawaii/keybinds.txt; }
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
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

case_ "the sheet: every line but the blank ones, a field to filter in (bare, as the launcher's: no prompt of its own), sized to its content, 24 lines, no cursor (info rows are only read)"
setup; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$K")"
has "$(cat "$REPO/bin/kawa-help")" 'kawa-menu --prompt "" --ghost "a key or a word" --fuzzy --caps --lines 24' "a field, bare but for its ghost; the keys keycaps"
eq "$(fz_arg prompt)" ""; eq "$(fz_arg width)" ""; eq "$(fz_arg lines)" 24; eq "$(fz_arg select)" ""
eq "$(fz_arg fuzzy)" set "what is typed finds by its letters in order too (\"wpa\": the wallpaper picker)"
eq "$(fz_rows | sed -n 2p)" "info		Super+Return	terminal (foot)" "line 1 is a binding, not a heading"
eq "$(fz_arg drop)" "" "centred"; fits
case_ "every binding an info row: no glyph, the key as its name, what it does as its detail (the panel's column), as the sheet says"
eq "$(fz_rows | grep '^info')" "$(python3 -I -c "$LINES" "$K")"
has "$(fz_rows)" "info		Super+1…9	"
case_ "every part under its icon and name: what follows a colon or is in brackets at the heading's end"
eq "$(fz_rows | grep -vc -e '^part	' -e '^info	')" 0 "nothing but parts and info rows (the panel spaces its parts)"
eq "$(fz_rows | head -n1)" "part	$ICON_TORII_SMALL	launch	" "the sheet starts with its first heading"
has "$(fz_rows)" "part	$ICON_CAMERA	screenshots	clipboard + ~/captures"
has "$(fz_rows)" "part	$ICON_DRIVE	drives	USB sticks, disks, SD cards"
has "$(fz_rows)" "part	$ICON_SPEAKER	sound, music, monitor	"
eq "$(fz_rows | grep -c '^part')" "$(grep -c '^─' "$K")"
case_ "each part's icon follows the first word of its name: launch the small torii, screenshots the camera, windows the window, workspaces the tile, sound the speaker, terminal the terminal, drives the drive, session the power icon, drawing the brush — the sheet's own nine, in order (yazi's keys are its own sheet's)"
eq "$(fz_rows | grep '^part' | cut -f2 | tr '\n' ' ')" \
  "$ICON_TORII_SMALL $ICON_CAMERA $ICON_WINDOW $ICON_TILE $ICON_SPEAKER $ICON_TERMINAL $ICON_DRIVE $ICON_POWER $ICON_BRUSH " \
  "launch, screenshots, windows, workspaces, sound, terminal, drives, session, drawing tablet"
eq "$(fz_rows | grep '^part' | cut -f2 | sort -u | wc -l)" 9 "no two parts share an icon"
case_ "a part of your own: the keycap"
setup; printf '%s\n' '── my keys ──' 'Super+F12               mine' >"$K"; answer esc; kawa-help
eq "$(fz_rows | head -n1)" "part	$ICON_KEYCAP	my keys	" "a name the sheet does not know: the keycap, not an icon of another part"

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

# ── the programs' sheets (~/.config/fedokawaii/keys/NAME.txt), the one you are in first ─────
SHEETS=$REPO/configs/home/.config/fedokawaii/keys
keys_setup() { setup; config .config/fedokawaii/keys; D=$XDG_RUNTIME_DIR/dwl-bar; mkdir -p "$D"; }
focus() {   # focus APPID TITLE — the focused window as kawa-dwlstatus keeps it (the title in the bar's markup)
  printf '{"text":"%s"}\n' "$1" >"$D/appid.json"
  printf '{"text":"<span line_height='"'"'14336'"'"'>%s</span>","class":["l0","r1"]}\n' "$2" >"$D/title.json"
}
parts() { fz_rows | awk -F'\t' '$1 == "part" && !seen[$3]++ { printf "%s ", $3 }'; }
ALL="launch screenshots windows workspaces sound, music, monitor terminal drives session drawing tablet "
case_ "no window focused (no files yet): the desktop's sheet first, then every program's, by its file's name"
keys_setup; answer esc; rc 0 kawa-help
eq "$(parts)" "${ALL}asobi bluetui books btop chess clipboard gdu lazygit lessons lesson mpv notes to-do nvim sketch system torrents typing visidata wallpaper wiremix yazi zathura "
case_ "yazi in a terminal (it titles itself \"Yazi: …\"): its keys first, then the desktop's, then the rest"
keys_setup; focus footclient "Yazi: ~/downloads"; answer esc; kawa-help
eq "$(parts)" "yazi ${ALL}asobi bluetui books btop chess clipboard gdu lazygit lessons lesson mpv notes to-do nvim sketch system torrents typing visidata wallpaper wiremix zathura "
eq "$(fz_rows | head -n2 | tail -n1)" "$(printf 'info\t\tj / k\tnext / previous file (arrow keys too)')" "its first row under its first part"
case_ "a program the shell named in the title (nvim, lazygit, vd): its keys first; a folder as the title, or a program with no sheet: the desktop's first"
for t in nvim:nvim lazygit:lazygit vd:visidata; do
  keys_setup; focus foot "${t%%:*}"; answer esc; kawa-help
  eq "$(parts | cut -d' ' -f1)" "${t#*:}" "titled ${t%%:*}"
done
for t in "~/dojo/fedokawaii" "btop2" "Yazi"; do
  keys_setup; focus footclient "$t"; answer esc; kawa-help; eq "$(parts | cut -d' ' -f1)" launch "titled $t"
done
case_ "one of ours by its app id: the notes (the to-do beside them), the clipboard, Super+U, Git lazygit, Disk usage gdu, Tables visidata, Torrents its own, zathura, mpv; Helium: the desktop's first"
for t in warm-notes:notes warm-clip:clipboard warm-system:system kawa-git:lazygit kawa-disk:gdu kawa-tables:visidata kawa-torrents:torrents org.pwmt.zathura:zathura mpv:mpv helium:launch; do
  keys_setup; focus "${t%%:*}" "a title"; answer esc; kawa-help
  eq "$(parts | cut -d' ' -f1)" "${t#*:}" "app id ${t%%:*}"
done
case_ "a popup of ours by its title (the wallpaper picker, the books), the file dialog by its locked titles (open file, save file …: yazi's), a job window (backup) the desktop's: their keys first"
for t in "float|wallpaper|wallpaper" "float|books|books" "kawa-dialog|open file|yazi" "kawa-dialog|save file|yazi" "kawa-dialog|open folders|yazi" "kawa-dialog|backup|launch" "float|tui|launch"; do
  IFS='|' read -r a ti want <<<"$t"
  keys_setup; focus "$a" "$ti"; answer esc; kawa-help
  eq "$(parts | cut -d' ' -f1)" "$want" "$a titled $ti"
done
eq "$(keys_setup; focus warm-notes notes; answer esc; kawa-help; parts | cut -d' ' -f1-3)" "notes to-do launch" "the notes' two parts, then the desktop's"
case_ "a program another one started titles itself (nvim from yazi or lazygit, lazygit in nvim's terminal): its keys first — in one of ours too, whose own name is back when it ends; quick settings' mixer and pairing windows by what they do"
for t in "footclient|nvim|nvim" "kawa-git|nvim|nvim" "kawa-git|Git|lazygit" "kawa-disk|nvim|nvim" "foot|lazygit|lazygit" "float|mixer|wiremix" "float|pair a device|bluetui" "warm-notes|nvim|notes"; do
  IFS='|' read -r a ti want <<<"$t"
  keys_setup; focus "$a" "$ti"; answer esc; kawa-help
  eq "$(parts | cut -d' ' -f1)" "$want" "$a titled $ti"
done
case_ "every row of every sheet is in the menu (none lost, none twice), its notes (# …) never; each program's parts under its own icon"
keys_setup; answer esc; kawa-help
want=$(cat "$HOME/.config/fedokawaii/keybinds.txt" "$SHEETS"/*.txt | grep -v -e '^#' -e '^─' -e '^[[:space:]]*$' | wc -l)
eq "$(fz_rows | grep -c '^info')" "$want"
eq "$(fz_rows | grep -c -e 'source:' -e '^info		# ')" 0 "a sheet's notes shown"
eq "$(fz_rows | awk -F'\t' '$1 == "part" { print $3 "=" $2 }' | sort -u | grep -E '^(yazi|nvim|lazygit|btop|wiremix|bluetui|visidata|gdu|zathura|mpv)=' | tr '\n' ' ')" \
  "bluetui=$ICON_BLUETOOTH btop=$ICON_CPU gdu=$ICON_USAGE lazygit=$ICON_BRANCH mpv=$ICON_MONITOR nvim=$ICON_CODE visidata=$ICON_SHEET wiremix=$ICON_SLIDERS yazi=$ICON_FOLDER zathura=$ICON_PAGES "
eq "$(fz_rows | awk -F'\t' '$1 == "part" { print $3 "=" $2 }' | sort -u | grep -E '^(notes|to-do|clipboard|wallpaper|books|system|lessons|lesson)=' | tr '\n' ' ')" \
  "books=$ICON_BOOK clipboard=$ICON_CLIPBOARD lesson=$ICON_MORTARBOARD lessons=$ICON_MORTARBOARD notes=$ICON_NOTE system=$ICON_SEC_SYSTEM to-do=$ICON_TODO wallpaper=$ICON_PICTURE " "our own screens"
eq "$(fz_rows | awk -F'\t' '$1 == "part" && $2 == "'"$ICON_KEYCAP"'"' | wc -l)" 0 "a program's part under the keycap (a part of your own)"
case_ "each program's sheet in the sheet's own columns: notes on top (#: the version, its command, its sources), the rules ending in column 67, each description at 24"
for k in "$SHEETS"/*.txt; do
  eq "$(grep '^── ' "$k" | python3 -I -c 'import sys; print(*sorted({len(l) for l in sys.stdin.read().splitlines()}))')" 67 "${k##*/}: rules"
  bad=$(python3 -I -c '
import sys
for l in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if l.strip() and not l.startswith(("── ", "#")) and not (l[23:24] == " " and l[24:25] not in ("", " ")):
        print(l)' "$k")
  eq "$bad" "" "${k##*/}: lines whose description is out of line"
  grep -q '^# source: ' "$k" && _ok || _no "${k##*/}: no source"
done

case_ "a home folder with a space in its name: the sheet still found"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"; answer esc; rc 0 kawa-help
eq "$(fz_rows | grep -c .)" "$(grep -cv '^[[:space:]]*$' "$HOME/.config/fedokawaii/keybinds.txt")"

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-help --help)" "every keybinding"; rc 0 kawa-help --help
rc 2 kawa-help extra; eq "$(fz_n)" 0

done_
