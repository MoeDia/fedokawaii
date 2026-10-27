#!/usr/bin/env bash
# tests/menus/test_menu.sh — kawa-menu, what every menu goes through: what it hands the panel
# (its fifo: the request, the caller; the panel decides one menu at a time — test_panel), what
# it prints back, wrong use; and the launcher (the panel's: kawa-menu --launcher writes one
# "toggle launcher" a press — every press reaches the panel, however fast, nothing waited for;
# the panel decides the rest: centred, its key or the torii again closes it, the click that
# closed it does not reopen it, lit while open — test_panel). The panel is fake_panel (a
# stand-in that reads the fifo and answers as each case says).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

menus_sandbox
rows=$'alpha\nbeta\ngamma'
pick() { printf '%s\n' "$rows" | kawa-menu "$@"; }   # pick ARGS — the three rows into the menu

# ── what the panel is told ────────────────────────────────────────────────────────────
case_ "plain: the panel's menu (kawa-panel --menu), list order kept, no option it was not given"
answer "row 1"; out=$(pick)
eq "$out" beta "the chosen row's text"
eq "$(fz_rows)" "$rows" "the rows reach the panel unchanged"
eq "$(fz_args)" "" "no options: centred, no title, no prompt (the panel's defaults)"
called '^kawa-panel --menu $'
eq "$(cat "$FZ/who.$(fz_n)")" test_menu.sh "the script that asked: the panel's toggle and the lit button go by it"

case_ "every option reaches the panel"
answer enter; out=$(pick --drop --title "pick one" --width 30 --lines 3 --select 2 --prompt "> " --index)
eq "$out" 2 "Enter on the --select line prints its number"
eq "$(fz_arg drop)" set "dropped from the bar (the panel places it: under the click, or the bar's right end)"
eq "$(fz_arg title)" "pick one"; eq "$(fz_arg width)" 30; eq "$(fz_arg lines)" 3
eq "$(fz_arg select)" 2; eq "$(fz_arg prompt)" "> "; eq "$(fz_arg index)" set
lacks "$(fz_args)" "anchor"; lacks "$(fz_args)" "margin"

case_ "the panel's own line format passes through as it is (parts, rows with detail and value, keys)"
lines=$'part\t天\tSharjah\train\nrow\t☼\tMon 19\thot\t31°\noff\t□\tnot now\nkey\t<\tback'
answer "row 1"; eq "$(printf '%s\n' "$lines" | kawa-menu --index)" 1; eq "$(fz_rows)" "$lines"
answer "row 1"; eq "$(printf '%s\n' "$lines" | kawa-menu)" "Mon 19" "without --index: the row's name"

case_ "no theme needed: kawa-menu reads no colours (the panel draws in the theme's)"
lacks "$(grep -v '^ *#' "$REPO/bin/kawa-menu")" "colors.sh"
rm "$HOME/.config/fedokawaii/current"
answer "row 0"; eq "$(pick)" alpha
ln -s themes/dark "$HOME/.config/fedokawaii/current"

case_ "an empty title passes as given (the panel draws none)"
answer "row 0"; pick --title "" >/dev/null
eq "$(fz_args | tr '\n' '|')" "--title||"

case_ "Esc, a click outside: nothing printed, exit 1"
answer esc; rc 1 pick; answer lost; rc 1 pick
answer esc; eq "$(pick --index)" ""

case_ "--index: typed text that matches nothing is no line number — dismissed"
answer "typed zeta"; rc 1 pick --index
answer "typed zeta"; eq "$(pick)" zeta "(without --index the text comes back: kawa-shrink's own size)"

case_ "index mode with the same row twice: the second one's own number"
answer "row 3"; eq "$(printf 'same\nother\nsame\nsame\n' | kawa-menu --index)" 3
answer "row 2"; eq "$(printf 'same\nother\nsame\n' | kawa-menu)" same

case_ "Japanese, Arabic, emoji and shell characters: rows and title pass through byte for byte"
printf -v odd '%s\n' '夜の音楽 — 坂本龍一' 'مرحبا بالعالم' '🎵 "quoted" $(touch '"$TMP"'/pwned) `id` \ end' ' -leading dash'
odd=${odd%$'\n'}
answer "row 2"; out=$(printf '%s\n' "$odd" | kawa-menu --title '音楽 · موسيقى $(id)' --width 40)
eq "$out" '🎵 "quoted" $(touch '"$TMP"'/pwned) `id` \ end'
eq "$(fz_rows)" "$odd"; eq "$(fz_arg title)" '音楽 · موسيقى $(id)'
[[ ! -e $TMP/pwned ]] && _ok || _no "a row ran as a command"
answer "row 3"; eq "$(printf '%s\n' "$odd" | kawa-menu)" " -leading dash" "a row starting with a dash is text"
answer "row 0"; eq "$(printf '%s\n' "$odd" | kawa-menu --index --width 12 --lines 2)" 0
eq "$(fz_arg width)" 12; eq "$(fz_arg lines)" 2

case_ "--help: the usage and the line format, exit 0"
out=$(kawa-menu --help); rc 0 kawa-menu --help
has "$out" "kawa-menu [--drop]"; has "$out" "--index"; has "$out" "part"; has "$out" "row|on|off|info GLYPH NAME [DETAIL [VALUE]]"
has "$out" "--width N   at least N columns of 7 px" "(the panel's column: kawa-panel's COL)"
eq "$(python3 -I -c 'import re,sys; print(re.search(r"^COL = (\d+)", open(sys.argv[1]).read(), re.M).group(1))' "$REPO/bin/kawa-panel")" 7
case_ "wrong use: exit 2 and no menu opens"
n=$(fz_n)
rc 2 kawa-menu --bogus; rc 2 kawa-menu --title; rc 2 kawa-menu --width
rc 2 kawa-menu --width wide; rc 2 kawa-menu --lines -3; rc 2 kawa-menu --select 1x
rc 2 kawa-menu --launcher --index; rc 2 kawa-menu --launcher --title x
eq "$(fz_n)" "$n"
has "$(kawa-menu --nope 2>&1)" "unknown option --nope"

case_ "the launcher: the panel's — one \"toggle launcher\" line to its fifo, exit 0 at once; no menu of its own, no other program"
n=$(fz_n); reset_calls; rc 0 kawa-menu --launcher; sleep 0.2
eq "$(grep -c . "$CALLS")" 1 "one line"; called '^kawa-panel toggle launcher$'; eq "$(fz_n)" "$n" "no menu asked for"
for w in fuzzel kawa-calc notify-send kawa-launcher.state; do lacks "$(grep -v '^ *#' "$REPO/bin/kawa-menu")" "$w"; done

case_ "no runtime folder: a menu cannot reach the panel — exit 1 at once, saying why; nor can the launcher"
o=$(printf 'a\n' | XDG_RUNTIME_DIR=$TMP/gone timeout 5 kawa-menu 2>&1); r=$?
[[ $r == 1 && $o == *"no runtime folder"* ]] && _ok || _no "rc $r: $o"
o=$(XDG_RUNTIME_DIR=$TMP/gone timeout 5 kawa-menu --launcher 2>&1); r=$?
[[ $r == 1 && $o == *"no panel to show the launcher"* ]] && _ok || _no "rc $r: $o"
case_ "nothing left behind in the runtime folder: the panel's pid file and fifo"
answer "row 0"; pick >/dev/null; kawa-menu --launcher; sleep 0.2
eq "$(cd "$XDG_RUNTIME_DIR" && find . -mindepth 1 ! -name kawa-panel.pid ! -name kawa-panel.in | sort)" ""
case_ "every request reaches the panel whole: 30 menus asked at once, each answered as its own"
pids=(); for i in {1..30}; do answer "row 1"; done
for i in {1..30}; do (printf 'x%s\ny%s\n' "$i" "$i" | kawa-menu >"$TMP/got.$i") & pids+=($!); done; wait "${pids[@]}"
ok=0; for i in {1..30}; do [[ $(cat "$TMP/got.$i") == "y$i" ]] && ((ok++)); done; eq "$ok" 30
case_ "kawa-menu ended (killed) while its menu is open: its request and answer fifo go with it"
n0=$(fz_n); answer hang; (printf 'a\nb\n' | kawa-menu) & m=$!
for _ in {1..40}; do [[ -e $FZ/hang.$((n0 + 1)) ]] && break; sleep 0.05; done
mp=$(cat "$FZ/hang.$(fz_n)"); kill "$mp"; wait "$m" 2>/dev/null
left=("$XDG_RUNTIME_DIR"/kawa-menu."$mp".*); [[ -e ${left[0]} ]] && _no "left: ${left[*]}" || _ok
case_ "the panel gone while a menu is open (killed): kawa-menu ends within a second, dismissed"
n0=$(fz_n); answer hang; (printf 'a\nb\n' | kawa-menu; echo "rc $?" >"$TMP/gone-rc") & m=$!
for _ in {1..40}; do [[ -e $FZ/hang.$((n0 + 1)) ]] && break; sleep 0.05; done
kill "$(cat "$XDG_RUNTIME_DIR/kawa-panel.pid")"; t0=$EPOCHREALTIME; wait "$m"
eq "$(cat "$TMP/gone-rc")" "rc 1"; t=$(( (${EPOCHREALTIME/./} - ${t0/./}) / 1000 )); ((t < 1500)) && _ok || _no "only after $t ms"
case_ "no panel running: one is started, the menu shown"
answer "row 1"; eq "$(pick)" beta
case_ "the launcher asks only for itself (the panel closes what it shows: no \"close\" line); a menu asks nothing else of it either"
reset_calls; kawa-menu --launcher; sleep 0.2
not_called '^kawa-panel close$'; called '^kawa-panel toggle launcher$'
reset_calls; answer "row 0"; pick >/dev/null; sleep 0.2; not_called '^kawa-panel close$'; not_called 'toggle'
case_ "a stale pid file (its pid someone else's): not the panel — that process untouched, a panel started, the launcher shown by it"
pp=$(cat "$XDG_RUNTIME_DIR/kawa-panel.pid"); sleep 30 & op=$!; echo "$op" >"$XDG_RUNTIME_DIR/kawa-panel.pid"
reset_calls; rc 0 kawa-menu --launcher; sleep 0.3; called '^kawa-panel toggle launcher$'
[[ -e /proc/$op ]] && _ok || _no "a stale pid file's process (not the panel) was touched"
np=$(cat "$XDG_RUNTIME_DIR/kawa-panel.pid"); [[ $np != "$op" && $np != "$pp" && -e /proc/$np ]] && _ok || _no "no new panel (pid file: $np)"
kill "$op" "$pp" 2>/dev/null

# ── the launcher: every press reaches the panel ─────────────────────────────────────────
case_ "its key pressed fast (dwl repeats no held key that opens it): every press reaches the panel as its own \"toggle launcher\", none waited on, none lost — the panel counts them (test_panel: open after an odd number)"
reset_calls; t0=$EPOCHREALTIME
for _ in {1..7}; do setsid -f kawa-menu --launcher </dev/null >/dev/null 2>&1; done
for _ in {1..100}; do (($(grep -c '^kawa-panel toggle launcher$' "$CALLS") >= 7)) && break; sleep 0.02; done
eq "$(grep -c '^kawa-panel toggle launcher$' "$CALLS")" 7
t=$(( (${EPOCHREALTIME/./} - ${t0/./}) / 1000 )); ((t < 1500)) && _ok || _no "only after $t ms"
reset_calls; for _ in {1..7}; do kawa-menu --launcher; done; sleep 0.2
eq "$(grep -c '^kawa-panel toggle launcher$' "$CALLS")" 7 "one after another: the same"
case_ "no panel running: the launcher starts one and asks it (as a menu does)"
kill "$(cat "$XDG_RUNTIME_DIR/kawa-panel.pid")"; sleep 0.1; reset_calls
rc 0 kawa-menu --launcher; sleep 0.3; called '^kawa-panel toggle launcher$'
answer "row 2"; eq "$(pick)" gamma "the same panel takes the next menu"

done_
