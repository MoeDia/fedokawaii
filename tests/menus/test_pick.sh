#!/usr/bin/env bash
# tests/menus/test_pick.sh — kawa-pick, the yazi file dialog, called exactly as
# xdg-desktop-portal-termfilechooser 1.4.3 calls it (portal.py: the same command line through
# /bin/sh, the same stand-in file for a save, the same reading of the answer into file://
# URIs). yazi is fake_yazi (told what you do in it); the floating window runs the dialog at once.
# Open one or several files, a folder or several, save (under the suggested name, over a name
# that is taken, into a folder, under a new name), cancel; odd names; what is left behind.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  menus_sandbox
  config .config/fedokawaii/yazi-pick .config/yazi .config/xdg-desktop-portal-termfilechooser
  W=$TMP/world P="$TMP/my files"; export W P
  mkdir -p "$W" "$P/gamma dir" "$P/odd 'dir' \$HOME" "$P/ünï 日本"
  touch "$P/alpha.txt" "$P/beta.txt" "$P/gamma dir/inner.txt" "$P/odd 'dir' \$HOME/x \"y\".txt" "$P/ünï 日本/ファイル.txt"
  echo "keep me" >"$P/old.pdf"
  : >"$W/yazi"; install -m 755 "$MD/fake_yazi" "$STUBS/yazi"
  # the floating window: the dialog runs in it at once, keys typed from $W/keys
  stub kawa-float '[ -e "$W/no-terminal" ] && exit 1
while [ "$1" != "--" ]; do shift; done; shift
"$@" <"$W/keys" >>"$W/screen" 2>&1; exit 0'
  : >"$W/keys"
  # the portal's config, as theme.sh renders it: the command to run
  PORTAL_CMD=$(sed -n 's/^cmd=//p' "$HOME/.config/xdg-desktop-portal-termfilechooser/config")
  mkdir -p "$HOME/.local/bin"; ln -sf "$REPO/bin/kawa-pick" "$PORTAL_CMD"
  export PORTAL_CMD PORTAL_OUT=$TMP/termfilechooser-$UID.portal PORTAL_DEBUG=0
}
does() { printf '%s\n' "$@" >>"$W/yazi"; }                # does STEPS… — what you do in each yazi
keys() { printf '%s' "$1" >"$W/keys"; }                    # keys TEXT — keys typed at its questions
# the portal: systemd --user's PATH (the stand-ins first, as if installed), no ~/.local/bin
portal() { PATH="$STUBS:/usr/bin:/bin" python3 -I "$MD/portal.py" "$@" 2>"$TMP/stderr"; }
uri() { python3 -I -c 'import sys; from urllib.parse import quote; print("uri file://" + quote(sys.argv[1].encode(), safe="/"))' "$1"; }
left() { find "$P" -newer "$TMP/stamp" -type f 2>/dev/null | sort; }   # files made during the pick
stamp() { touch "$TMP/stamp"; sleep 0.01; }

# ── open ──────────────────────────────────────────────────────────────────────────────
case_ "open one file: Enter on it — its URI, nothing else"
setup; does "choose alpha.txt"; out=$(portal open 0 0 "$P")
eq "$out" "$(uri "$P/alpha.txt")"
called "^yazi open1 $P$"; called "^kawa-float --dialog --locked-title open file 100x31 -- $PORTAL_CMD --inside open1 $P "
case_ "open one, Enter on a folder: into it (yazi again, there), then the file"
setup; does "choose gamma dir" "choose gamma dir/inner.txt"; out=$(portal open 0 0 "$P")
eq "$out" "$(uri "$P/gamma dir/inner.txt")"; called "^yazi open1 $P/gamma dir$"
case_ "open one, two marked: only the first (an app asking for one file hangs on more)"
setup; does "choose alpha.txt|beta.txt"; eq "$(portal open 0 0 "$P")" "$(uri "$P/alpha.txt")"
case_ "open several: every marked file, in order; marked folders left out"
setup; does "choose beta.txt|gamma dir|alpha.txt"; out=$(portal open 1 0 "$P")
eq "$out" "$(uri "$P/beta.txt")"$'\n'"$(uri "$P/alpha.txt")"; called "^kawa-float --dialog --locked-title open files "
case_ "open several, only folders marked: into the first (nothing to hand back yet)"
setup; does "choose gamma dir|ünï 日本" "choose ünï 日本/ファイル.txt"; out=$(portal open 1 0 "$P")
eq "$out" "$(uri "$P/ünï 日本/ファイル.txt")" "Japanese and accents, percent-encoded by the portal"
case_ "open: Esc (or q) — cancelled: the answer file is empty, exit 0"
setup; does esc; eq "$(portal open 0 0 "$P")" cancelled
setup; does "q"; eq "$(portal open 1 0 "$P")" cancelled
case_ "open, starting in a folder with quotes, \$ and spaces in its name (the portal's shell quoting)"
setup; does "choose odd 'dir' \$HOME/x \"y\".txt"; out=$(portal open 0 0 "$P/odd 'dir' \$HOME")
eq "$out" "$(uri "$P/odd 'dir' \$HOME/x \"y\".txt")"; called "^yazi open1 $P/odd 'dir' \\\$HOME$"
case_ "open, no folder suggested (the portal hands an empty path): from home"
setup; does esc; portal open 0 0 "" >/dev/null; called "^yazi open1 $HOME$"
case_ "a chosen file with a line break in its name: said, and the dialog stays (never two bogus paths)"
setup; touch "$P/two"$'\n'"lines.txt"; does 'choose two\nlines.txt' "choose beta.txt"; keys ""
out=$(portal open 0 0 "$P"); eq "$out" "$(uri "$P/beta.txt")"
eq "$(grep -c "^yazi open1 $P\$" "$CALLS")" 2 "yazi again, in the same folder"
has "$(cat "$W/screen")" "a name with a line break cannot be passed on"

# ── folders ───────────────────────────────────────────────────────────────────────────
case_ "folder: Enter on a folder takes it"
setup; does "choose gamma dir"; eq "$(portal open 0 1 "$P")" "$(uri "$P/gamma dir")"; called "^yazi folder1 $P$"
called "^kawa-float --dialog --locked-title open folder "
case_ "folder: q takes the folder you are in"
setup; does "q gamma dir"; eq "$(portal open 0 1 "$P")" "$(uri "$P/gamma dir")"
case_ "folder: Enter on a file takes the folder it is in"
setup; does "choose alpha.txt"; eq "$(portal open 0 1 "$P")" "$(uri "$P")"
case_ "folders (several): each once, files counted as their folder"
setup; does "choose gamma dir|alpha.txt|beta.txt|ünï 日本"; out=$(portal open 1 1 "$P")
eq "$out" "$(uri "$P/gamma dir")"$'\n'"$(uri "$P")"$'\n'"$(uri "$P/ünï 日本")"; called "^yazi folderN "
case_ "folder: Esc cancels"
setup; does esc; eq "$(portal open 0 1 "$P")" cancelled

# ── save ──────────────────────────────────────────────────────────────────────────────
case_ "save: the stand-in under the suggested name, in the dialog's words; Enter saves it there"
setup; stamp; does "choose report.pdf"; out=$(portal save "$P" report.pdf)
eq "$out" "made $P/report.pdf"$'\n'"$(uri "$P/report.pdf")"
has "$(head -n1 "$P/report.pdf")" "the file being saved" "kawa-pick's note replaces the portal's instructions"
called "^yazi save $P/report.pdf$"; called "^kawa-float --dialog --locked-title save file "
eq "$(left)" "$P/report.pdf" "nothing else made"
case_ "save under a name that is taken: report (1).pdf beside it (the portal's report.pdf_ renamed)"
setup; echo "mine" >"$P/report.pdf"; stamp; does "choose report (1).pdf"; out=$(portal save "$P" report.pdf)
has "$out" "made $P/report.pdf_"; has "$out" "$(uri "$P/report (1).pdf")"
eq "$(cat "$P/report.pdf")" mine "the file that was there untouched"
[[ ! -e "$P/report.pdf_" ]] && _ok || _no "the portal's report.pdf_ left behind"
case_ "… and both report.pdf and report (1).pdf taken: report (2).pdf"
setup; echo a >"$P/report.pdf"; echo b >"$P/report (1).pdf"; does "choose report (2).pdf"
has "$(portal save "$P" report.pdf)" "$(uri "$P/report (2).pdf")"
eq "$(cat "$P/report (1).pdf")" b
case_ "save over an existing file: Enter on it asks first — y replaces"
setup; stamp; does "choose old.pdf"; keys y; out=$(portal save "$P" report.pdf)
has "$out" "$(uri "$P/old.pdf")"; has "$(cat "$W/screen")" "replace old.pdf?"
eq "$(left)" "" "the stand-in gone"
case_ "… n: back in the dialog; then Esc — cancelled, nothing changed, nothing left"
setup; stamp; does "choose old.pdf" esc; keys n; out=$(portal save "$P" report.pdf)
has "$out" cancelled; eq "$(cat "$P/old.pdf")" "keep me"; eq "$(left)" ""
case_ "save with a suggested name with spaces, quotes, unicode: saved under exactly that name"
setup; name="my report — 報告 'final' \$(x).pdf"; does "choose $name"; out=$(portal save "$P" "$name")
has "$out" "$(uri "$P/$name")"; [[ -f "$P/$name" ]] && _ok || _no "not saved under [$name]"
case_ "save with a suggested name that is a path, or empty: the portal's own rule (the last part / termfilechooser.tmp)"
setup; does "choose evil.pdf"; has "$(portal save "$P" "../../evil.pdf")" "$(uri "$P/evil.pdf")"
setup; does "choose termfilechooser.tmp"; has "$(portal save "$P" "")" "$(uri "$P/termfilechooser.tmp")"
case_ "save, cancelled (Esc): the stand-in removed (no empty file left where it was)"
setup; stamp; does esc; out=$(portal save "$P" report.pdf); has "$out" cancelled; eq "$(left)" ""
case_ "save into a folder: Enter on it takes the file there; Enter then saves it"
setup; stamp; does "choose gamma dir" "choose gamma dir/report.pdf"; out=$(portal save "$P" report.pdf)
has "$out" "$(uri "$P/gamma dir/report.pdf")"; called "^yazi save $P/gamma dir/report.pdf$"
eq "$(left)" "$P/gamma dir/report.pdf" "only the saved file"
case_ "save into a folder that has the name already: report (1).pdf there"
setup; echo x >"$P/gamma dir/report.pdf"; does "choose gamma dir" "choose gamma dir/report (1).pdf"
has "$(portal save "$P" report.pdf)" "$(uri "$P/gamma dir/report (1).pdf")"; eq "$(cat "$P/gamma dir/report.pdf")" x
case_ "save into a folder, then Esc: removed from both places"
setup; stamp; does "choose gamma dir" esc; has "$(portal save "$P" report.pdf)" cancelled; eq "$(left)" ""
case_ "save, renamed in yazi (r), then Enter on it: saved under the new name"
setup; stamp; does "mv report.pdf => notes 2026.pdf ; choose notes 2026.pdf"; out=$(portal save "$P" report.pdf)
has "$out" "$(uri "$P/notes 2026.pdf")"; eq "$(left)" "$P/notes 2026.pdf"
case_ "save, renamed in yazi, then Esc: the renamed stand-in removed too"
setup; stamp; does "mv report.pdf => renamed.pdf ; esc"; has "$(portal save "$P" report.pdf)" cancelled
eq "$(left)" ""
case_ "save, two marked: one file to save — asked again; then Enter on the stand-in"
setup; does "choose alpha.txt|beta.txt" "choose report.pdf"; out=$(portal save "$P" report.pdf)
has "$out" "$(uri "$P/report.pdf")"; eq "$(grep -c '^yazi save' "$CALLS")" 2
case_ "save, a chosen name with a line break: said, back in the dialog, the save still works"
setup; touch "$P/a"$'\n'"b.pdf"; does 'choose a\nb.pdf' "choose report.pdf"
has "$(portal save "$P" report.pdf)" "$(uri "$P/report.pdf")"
case_ "save: never answers a folder or a missing file (the portal would hang the app)"
setup; does "choose gamma dir" "choose gamma dir" "choose report.pdf"; out=$(portal save "$P" report.pdf)
lacks "$out" error; lacks "$out" "directory"

# ── the answer file, the window, what goes wrong ─────────────────────────────────────
case_ "the answer file: absolute paths, one a line, each ending in a line break, nothing more"
setup; does "choose beta.txt|alpha.txt"; out=$TMP/answer.out
PATH="$STUBS:/usr/bin:/bin" "$PORTAL_CMD" 1 0 0 "$P" "$out" 0
eq "$(head -c1 "$out")" / "an absolute path"
eq "$(cat "$out")" "$P/beta.txt"$'\n'"$P/alpha.txt"; eq "$(tail -c1 "$out" | od -An -c | tr -d ' ')" '\n'
case_ "the answer file is made (empty) even when nothing is chosen, and when it was not there"
setup; does esc; rm -f "$TMP/new.out"; PATH="$STUBS:/usr/bin:/bin" "$PORTAL_CMD" 0 0 0 "$P" "$TMP/new.out" 0
[[ -e $TMP/new.out && ! -s $TMP/new.out ]] && _ok || _no "no empty answer file"
case_ "an answer file left from an earlier pick is emptied first"
setup; echo "$P/stale" >"$TMP/old.out"; does esc; PATH="$STUBS:/usr/bin:/bin" "$PORTAL_CMD" 0 0 0 "$P" "$TMP/old.out" 0
eq "$(cat "$TMP/old.out")" ""
case_ "the dialog's yazi: your theme, init.lua and plugins, the dialog's keys and its Enter/Esc plugin"
setup; does esc; portal open 0 0 "$P" >/dev/null
has "$(cat "$W/yazi-config")" "./keymap.toml -> $HOME/.config/fedokawaii/yazi-pick/keymap.toml"
has "$(cat "$W/yazi-config")" "./plugins/kawa-pick.yazi -> $HOME/.config/fedokawaii/yazi-pick/kawa-pick.yazi"
has "$(cat "$W/yazi-config")" "./theme.toml -> $HOME/.config/yazi/theme.toml"
has "$(cat "$W/yazi-config")" "./init.lua -> $HOME/.config/yazi/init.lua"
has "$(cat "$W/yazi-config")" "./plugins/drives.yazi -> $HOME/.config/yazi/plugins/drives.yazi"
case_ "the dialog's keymap parses (TOML) and binds Enter and Esc to its plugin, M to the drives and g d to ~/Drives"
out=$(python3 -I - "$HOME/.config/fedokawaii/yazi-pick/keymap.toml" <<'PY'
import sys, tomllib
k = tomllib.load(open(sys.argv[1], "rb"))["mgr"]["prepend_keymap"]
for b in k:
    on = b["on"] if isinstance(b["on"], str) else " ".join(b["on"])
    print(f"{on} = {b['run']}")
PY
)
has "$out" "<Enter> = plugin kawa-pick"; has "$out" "<Esc> = plugin kawa-pick -- esc"
has "$out" "M = plugin drives"; has "$out" "g d = cd ~/Drives"
[[ -f $HOME/.config/fedokawaii/yazi-pick/kawa-pick.yazi/main.lua && -f $HOME/.config/yazi/plugins/drives.yazi/main.lua ]] \
  && _ok || _no "a plugin the keymap names is missing"
case_ "nothing left behind: no work folder in the runtime folder"
eq "$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'kawa-pick.*' | wc -l)" 0
case_ "yazi missing: a critical notice, exit 1 (the portal: an error, the stand-in removed)"
setup; p=$(without yazi); stamp
out=$(PATH="$p" python3 -I "$MD/portal.py" save "$P" report.pdf 2>/dev/null)
has "$out" "error"; eq "$(left)" ""
called 'notify-send -a desktop -u critical file picker yazi is missing — fedokawaii repair puts it back'
case_ "no terminal window could open: a critical notice, cancelled"
setup; : >"$W/no-terminal"; eq "$(portal open 0 0 "$P")" cancelled
called 'notify-send -a desktop -u critical file picker no terminal window opened'
case_ "the portal's debug flag (1): a trace on stderr"
setup; does esc; PORTAL_DEBUG=1 portal open 0 0 "$P" >/dev/null; has "$(cat "$TMP/stderr")" "+ "
case_ "--help: what it is, exit 0; called wrongly: the usage, exit 2"
setup; has "$(kawa-pick --help)" "the file dialog"; rc 0 kawa-pick --help
rc 2 kawa-pick; rc 2 kawa-pick 0 0 0 "$P"; rc 2 kawa-pick --inside open1 "$P"
has "$(kawa-pick 2>&1)" "usage: kawa-pick MULTIPLE DIRECTORY SAVE PATH OUT"
case_ "the portal's shell gets the command line it builds from the config (cmd=… in the home)"
eq "$PORTAL_CMD" "$HOME/.local/bin/kawa-pick"

done_
