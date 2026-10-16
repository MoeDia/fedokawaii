#!/usr/bin/env bash
# tests/menus/test_menu.sh — kawa-menu, the fuzzel wrapper every menu uses: what it hands
# fuzzel, what it prints back, wrong use, and one menu at a time (its key again closes it,
# another menu takes its place, a held key is one press, a click on its own bar button
# closes it). fuzzel is fake_fuzzel, answering as each case says.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

menus_sandbox
rows=$'alpha\nbeta\ngamma'
pick() { printf '%s\n' "$rows" | kawa-menu "$@"; }   # pick ARGS — the three rows into the menu

# ── what fuzzel is told ───────────────────────────────────────────────────────────────
case_ "plain: dmenu, list order kept, as few lines as rows, the quiet title colour, no prompt"
answer "row 1"; out=$(pick)
eq "$out" beta "the chosen row's text"
eq "$(fz_rows)" "$rows" "the rows reach fuzzel unchanged"
for a in dmenu no-sort minimal-lines hide-prompt; do eq "$(fz_arg "$a")" set "--$a"; done
eq "$(fz_arg message-color)" 877f6fff "the dark theme's muted colour"
eq "$(fz_arg anchor)" "" "centred (no anchor)"; eq "$(fz_arg mesg)" "" "no title"

case_ "every option reaches fuzzel"
answer enter; out=$(pick --drop --title "pick one" --width 30 --lines 3 --select 2 --prompt "> " --index)
eq "$out" 2 "Enter on the pre-selected row prints its number"
eq "$(fz_arg anchor)" top-right; eq "$(fz_arg x-margin)" 6; eq "$(fz_arg y-margin)" 6
eq "$(fz_arg mesg)" "pick one"; eq "$(fz_arg width)" 30; eq "$(fz_arg lines)" 3
eq "$(fz_arg select-index)" 2; eq "$(fz_arg prompt)" "> "; eq "$(fz_arg hide-prompt)" "" "a prompt shown"
eq "$(fz_arg index)" set

case_ "the light theme: its own muted colour for the title"
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
. "$HOME/.config/fedokawaii/themes/light/colors.sh"
answer "row 0"; pick --title x >/dev/null
eq "$(fz_arg message-color)" "${C_MUTED}ff"
ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
case_ "no theme at all yet: the dark theme's colour"
rm "$HOME/.config/fedokawaii/current"; answer "row 0"; pick >/dev/null
eq "$(fz_arg message-color)" 877f6fff
ln -s themes/dark "$HOME/.config/fedokawaii/current"

case_ "an empty title is no title (not a blank line on top)"
answer "row 0"; pick --title "" >/dev/null
eq "$(fz_arg mesg)" ""

case_ "Esc, a right click, a click outside: nothing printed, exit 1"
answer esc; rc 1 pick; answer lost; rc 1 pick; forget
answer esc; eq "$(pick --index)" ""

case_ "--index: typed text that matches nothing is no line number — dismissed"
answer "typed zeta"; rc 1 pick --index
answer "typed zeta"; eq "$(pick)" zeta "(without --index the text comes back: kawa-help ignores it)"

case_ "index mode with the same row twice: the second one's own number"
answer "row 3"; eq "$(printf 'same\nother\nsame\nsame\n' | kawa-menu --index)" 3
answer "row 2"; eq "$(printf 'same\nother\nsame\n' | kawa-menu)" same

case_ "Japanese, Arabic, emoji and shell characters: rows and title pass through byte for byte"
printf -v odd '%s\n' '夜の音楽 — 坂本龍一' 'مرحبا بالعالم' '🎵 "quoted" $(touch '"$TMP"'/pwned) `id` \ end' ' -leading dash'
odd=${odd%$'\n'}
answer "row 2"; out=$(printf '%s\n' "$odd" | kawa-menu --title '音楽 · موسيقى $(id)' --width 40)
eq "$out" '🎵 "quoted" $(touch '"$TMP"'/pwned) `id` \ end'
eq "$(fz_rows)" "$odd"; eq "$(fz_arg mesg)" '音楽 · موسيقى $(id)'
[[ ! -e $TMP/pwned ]] && _ok || _no "a row ran as a command"
answer "row 3"; eq "$(printf '%s\n' "$odd" | kawa-menu)" " -leading dash" "a row starting with a dash is text"
answer "row 0"; eq "$(printf '%s\n' "$odd" | kawa-menu --index --width 12 --lines 2)" 0
eq "$(fz_arg width)" 12; eq "$(fz_arg lines)" 2

case_ "--help: the usage, exit 0"
out=$(kawa-menu --help); rc 0 kawa-menu --help
has "$out" "kawa-menu [--drop]"; has "$out" "--index"
case_ "wrong use: exit 2 and fuzzel never opens"
n=$(fz_n)
rc 2 kawa-menu --bogus; rc 2 kawa-menu --title; rc 2 kawa-menu --width
rc 2 kawa-menu --width wide; rc 2 kawa-menu --lines -3; rc 2 kawa-menu --select 1x
eq "$(fz_n)" "$n"
has "$(kawa-menu --nope 2>&1)" "unknown option --nope"

case_ "fuzzel missing: exit 1 and a notice that says so"
p=$(without fuzzel); reset_calls
PATH=$p rc 1 pick
called 'notify-send -a desktop -u critical Menus fuzzel is missing'
install -m 755 "$MD/fake_fuzzel" "$STUBS/fuzzel"

case_ "no runtime folder (XDG_RUNTIME_DIR unset): the menu still works"
answer "row 2"; eq "$(env -u XDG_RUNTIME_DIR bash -c 'printf "a\nb\nc\n" | kawa-menu --index')" 2

case_ "a runtime folder that is not there, or a record that cannot be written: the menu still works"
answer "row 1"; eq "$(XDG_RUNTIME_DIR=$TMP/gone pick)" beta
forget; mkdir "$XDG_RUNTIME_DIR/kawa-menu-$WAYLAND_DISPLAY.state"
answer "row 2"; eq "$(pick --index)" 2
rmdir "$XDG_RUNTIME_DIR/kawa-menu-$WAYLAND_DISPLAY.state"

case_ "nothing left behind in the runtime folder: its record and fuzzel's lock only"
eq "$(find "$XDG_RUNTIME_DIR" -mindepth 1 ! -name fuzzel-wayland-test.lock ! -name kawa-menu-wayland-test.state)" ""

case_ "fuzzel.ini (every menu's look) passes the real fuzzel's own check, in both themes"
real=$(PATH=/usr/local/bin:/usr/bin:/bin command -v fuzzel || ls /opt/f44/bin/fuzzel 2>/dev/null)
if [[ -n $real ]]; then
  config .config/fuzzel/fuzzel.ini
  for th in dark light; do
    ln -sfn "themes/$th" "$HOME/.config/fedokawaii/current"
    LD_LIBRARY_PATH=${real%/bin/fuzzel}/lib "$real" --check-config --config="$HOME/.config/fuzzel/fuzzel.ini" >/dev/null 2>&1 \
      && _ok || _no "fuzzel --check-config fails with the $th theme"
  done
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
else echo "  (no real fuzzel here: fuzzel.ini not checked)"; fi

# ── one menu at a time ────────────────────────────────────────────────────────────────
# two menus as scripts of their own (the menu knows which script asked); each says how its
# menu ended in $TMP/ended
fresh() {
  local m
  menus_sandbox; mkdir -p "$TMP/bin"; : >"$TMP/ended"
  for m in quick calendar; do
    printf '#!/usr/bin/env bash\nprintf "one\\ntwo\\n" | kawa-menu --index >/dev/null; echo "%s $?" >>"%s"\n' "$m" "$TMP/ended" >"$TMP/bin/$m"
    chmod 755 "$TMP/bin/$m"
  done
}
waitfor() { local _; for _ in {1..100}; do [[ -e $1 ]] && return 0; sleep 0.05; done; return 1; }
alive() { [[ -e /proc/$1 && $(cat "/proc/$1/comm" 2>/dev/null) == fuzzel ]]; }
at() { local ms=$1; shift; KAWA_MENU_TIME=$((1000000000000 + ms * 1000)) "$@"; }   # at MS CMD — CMD MS ms in
open_one() {   # open_one MS MENU — MENU on screen from MS ms (fuzzel open, $hp, until closed); $bg its script
  local n=$(($(fz_n) + 1))
  answer hang; at "$1" "$TMP/bin/$2" & bg=$!
  waitfor "$FZ/hang.$n" || _no "the menu did not open"; hp=$(cat "$FZ/hang.$n" 2>/dev/null)
}

case_ "its own key again (a second later, by the clock): the menu closes, no second one opens"
fresh; open_one 0 quick
sleep 0.6; "$TMP/bin/quick"; wait "$bg"
eq "$(fz_n)" 1 "no second fuzzel"
alive "$hp" && _no "the first menu is still open" || _ok
eq "$(sort "$TMP/ended" | tr '\n' ' ')" "quick 1 quick 1 " "both end as dismissed"
case_ "… the same, its time stood in for (1.2 s later)"
fresh; open_one 0 quick; at 1200 "$TMP/bin/quick"; wait "$bg"
alive "$hp" && _no "still open" || _ok; eq "$(fz_n)" 1

case_ "another menu's key: the open one closes at once, the other takes its place"
fresh; open_one 0 quick
answer "row 1"; at 100 "$TMP/bin/calendar"; wait "$bg"
alive "$hp" && _no "quick settings still open" || _ok
eq "$(fz_n)" 2; has "$(cat "$TMP/ended")" "calendar 0"; has "$(cat "$TMP/ended")" "quick 1"

case_ "a key held down (dwl repeats it: 300 ms, then every 29 ms, for 2 s): one press, the menu stays open"
fresh; open_one 0 quick
for ((t = 300; t < 2300; t += 29)); do at "$t" "$TMP/bin/quick"; done
alive "$hp" && _ok || _no "the held key closed the menu"
eq "$(fz_n)" 1 "no other menu"
eq "$(grep -c 'quick 1' "$TMP/ended")" 69 "every repeat ends at once"
case_ "… let go, then pressed again: it closes; held on that press too: it stays closed"
at 3000 "$TMP/bin/quick"
for ((t = 3300; t < 4000; t += 29)); do at "$t" "$TMP/bin/quick"; done
wait "$bg"; alive "$hp" && _no "still open" || _ok
eq "$(fz_n)" 1 "the repeats after closing it did not open it again"
case_ "… let go again, pressed once more: it opens"
answer "row 0"; at 5000 "$TMP/bin/quick"; eq "$(fz_n)" 2; eq "$(tail -n1 "$TMP/ended")" "quick 0"
case_ "a burst of 20 at the same moment (real time, a busy machine): the menu stays open, each ends"
fresh; open_one 0 quick
pids=(); for _ in {1..20}; do at 200 "$TMP/bin/quick" 2>/dev/null & pids+=($!); done; wait "${pids[@]}"
alive "$hp" && _ok || _no "the burst closed the menu"
eq "$(grep -c 'quick 1' "$TMP/ended")" 20 "every one of the burst ends at once"
kill "$hp" 2>/dev/null; wait "$bg"

case_ "a click outside that lands on its own bar button: closed, and the click's own call does not reopen it"
fresh; answer lost; at 0 "$TMP/bin/quick"
at 250 "$TMP/bin/quick"
eq "$(fz_n)" 1 "the same click's second menu does not open"
eq "$(tr '\n' ' ' <"$TMP/ended")" "quick 1 quick 1 "
case_ "… a moment later, its button opens it as usual"
answer "row 0"; at 1500 "$TMP/bin/quick"
eq "$(fz_n)" 2; eq "$(tail -n1 "$TMP/ended")" "quick 0"
case_ "a click outside on another menu's button: that one opens"
fresh; answer lost "row 1"; at 0 "$TMP/bin/quick"; at 150 "$TMP/bin/calendar"
eq "$(fz_n)" 2; eq "$(tail -n1 "$TMP/ended")" "calendar 0"
case_ "Esc, then its key at once: it opens again (Esc is not a click on its button)"
fresh; answer esc "row 0"; at 0 "$TMP/bin/quick"; at 100 "$TMP/bin/quick"
eq "$(fz_n)" 2; eq "$(tail -n1 "$TMP/ended")" "quick 0"
case_ "a choice, and the menu reopens at once (quick settings after a toggle, the audio taps)"
fresh; answer "row 1" "row 0" "row 1"; at 0 "$TMP/bin/quick"; at 50 "$TMP/bin/quick"; at 100 "$TMP/bin/quick"
eq "$(fz_n)" 3; eq "$(tr '\n' ' ' <"$TMP/ended")" "quick 0 quick 0 quick 0 "

case_ "the launcher (a plain fuzzel, not a menu's) is open: left alone, the menu does not open"
fresh; exec 7>>"$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"; flock 7
at 0 "$TMP/bin/quick" 2>/dev/null; eq "$(tail -n1 "$TMP/ended")" "quick 1"
case_ "… Esc closes the launcher, the menu's key at once: it opens (that was no click on its button)"
exec 7>&-
answer "row 1"; at 300 "$TMP/bin/quick"; eq "$(tail -n1 "$TMP/ended")" "quick 0"

case_ "fuzzel's lock file there but not ours to open (made by root): the menu still opens"
fresh; if ((EUID)); then : >"$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"; chmod 000 "$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"
else mkdir "$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"; fi      # (root opens anything; a folder it cannot lock as a file)
answer "row 0"; at 0 "$TMP/bin/quick" 2>/dev/null; eq "$(tail -n1 "$TMP/ended")" "quick 0"
rm -rf "$XDG_RUNTIME_DIR/fuzzel-$WAYLAND_DISPLAY.lock"

case_ "a record left by a menu killed mid-way, its pid now someone else's: ignored, nothing killed"
fresh; sleep 30 & other=$!
printf '%s %s open %s\n' "$other" "${EPOCHREALTIME//[!0-9]/}" "$TMP/bin/quick" >"$XDG_RUNTIME_DIR/kawa-menu-$WAYLAND_DISPLAY.state"
answer "row 1"; "$TMP/bin/quick"
eq "$(tail -n1 "$TMP/ended")" "quick 0" "the menu opened"
[[ -e /proc/$other ]] && _ok || _no "an unrelated process was killed"
kill "$other"
case_ "a corrupt record (garbage, a pid of -1): ignored, nothing killed"
: >"$TMP/ended"
for junk in "-1 0 open $TMP/bin/quick" "garbage" "" $'\x01\x02 x y'; do
  printf '%s\n' "$junk" >"$XDG_RUNTIME_DIR/kawa-menu-$WAYLAND_DISPLAY.state"
  answer "row 0"; "$TMP/bin/quick"
done
eq "$(grep -c 'quick 0' "$TMP/ended")" 4 "the menu opened every time"

done_
