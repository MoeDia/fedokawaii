#!/usr/bin/env bash
# tests/menus/test_menu.sh — kawa-menu, what every menu goes through: what it hands the panel
# (its fifo: the request, the caller; the panel decides one menu at a time — test_panel), what
# it prints back, wrong use; and the launcher (fuzzel): centred, its key or the torii again
# closes it, every press counts however fast, the click on the torii that closed it does not reopen it,
# and a fast clicker's clicks each open or close it. The panel is fake_panel (a stand-in that
# reads the fifo and answers as each case says), fuzzel fake_fuzzel.
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
called '^kawa-panel --menu $'; not_called '^fuzzel'
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
answer esc; rc 1 pick; answer lost; rc 1 pick; forget
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
has "$out" "kawa-menu [--drop]"; has "$out" "--index"; has "$out" "part"; has "$out" "row|on|off GLYPH NAME [DETAIL [VALUE]]"
case_ "wrong use: exit 2 and no menu opens"
n=$(fz_n)
rc 2 kawa-menu --bogus; rc 2 kawa-menu --title; rc 2 kawa-menu --width
rc 2 kawa-menu --width wide; rc 2 kawa-menu --lines -3; rc 2 kawa-menu --select 1x
rc 2 kawa-menu --launcher --index; rc 2 kawa-menu --launcher --title x
eq "$(fz_n)" "$n"
has "$(kawa-menu --nope 2>&1)" "unknown option --nope"

case_ "fuzzel missing: the menus open all the same (the panel's); the launcher says it is missing"
p=$(without fuzzel); reset_calls
answer "row 1"; eq "$(PATH=$p pick)" beta
PATH=$p rc 1 kawa-menu --launcher
called 'notify-send -a desktop -u critical -- .*  menus fuzzel is missing'
install -m 755 "$MD/fake_fuzzel" "$STUBS/fuzzel"

case_ "no runtime folder: a menu cannot reach the panel — exit 1 at once, saying why; the launcher opens all the same"
o=$(printf 'a\n' | XDG_RUNTIME_DIR=$TMP/gone timeout 5 kawa-menu 2>&1); r=$?
[[ $r == 1 && $o == *"no runtime folder"* ]] && _ok || _no "rc $r: $o"
reset_calls; answer esc; rc 1 env XDG_RUNTIME_DIR=$TMP/gone timeout 5 kawa-menu --launcher
called '^fuzzel'; eq "$(fz_n)" "$(fz_n)"
case_ "nothing left behind in the runtime folder: the panel's pid file and fifo, the launcher's record and fuzzel's lock"
answer "row 0"; pick >/dev/null; answer esc; kawa-menu --launcher
eq "$(cd "$XDG_RUNTIME_DIR" && find . -mindepth 1 ! -name fuzzel-wayland-test.lock ! -name kawa-launcher.state ! -name kawa-panel.pid ! -name kawa-panel.in | sort)" ""
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
case_ "the launcher closes what the panel shows first (a \"close\" line); a menu asks nothing else of it"
reset_calls; answer esc; kawa-menu --launcher; sleep 0.2
called '^kawa-panel close$'
reset_calls; answer "row 0"; pick >/dev/null; sleep 0.2; not_called '^kawa-panel close$'
pp=$(cat "$XDG_RUNTIME_DIR/kawa-panel.pid"); sleep 30 & op=$!; echo "$op" >"$XDG_RUNTIME_DIR/kawa-panel.pid"
reset_calls; answer esc; kawa-menu --launcher; sleep 0.2; not_called 'kawa-panel close'
[[ -e /proc/$op ]] && _ok || _no "a stale pid file's process (not the panel) was touched"
kill "$op"; echo "$pp" >"$XDG_RUNTIME_DIR/kawa-panel.pid"

case_ "fuzzel.ini (the launcher's look) passes the real fuzzel's own check, in both themes"
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

# ── the launcher: one at a time ───────────────────────────────────────────────────────
R=$XDG_RUNTIME_DIR
waitfor() { local _; for _ in {1..100}; do [[ -e $1 ]] && return 0; sleep 0.02; done; return 1; }
open_fz() { [[ -e $FZ/hang.$(fz_n) && -e /proc/$(cat "$FZ/hang.$(fz_n)") ]]; }   # the launcher on screen
press() { echo "24 5 HEADLESS-1 0 1920" >"$R/dwl-pointer.new"; mv -f "$R/dwl-pointer.new" "$R/dwl-pointer"; }   # dwl: a press on the bar
at() { local ms=$1; shift; KAWA_MENU_TIME=$((1000000000000 + ms * 1000)) "$@"; }   # at MS CMD — CMD MS ms in (the clock stood in for)
fresh() { menus_sandbox; R=$XDG_RUNTIME_DIR; rm -f "$R"/kawa-launcher.*; }
case_ "the launcher: in the middle of the screen (fuzzel's own place) — from the torii too"
fresh; press; answer esc; kawa-menu --launcher
eq "$(fz_args)" "--launch-prefix=kawa-calc --launch" "no output, anchor or margin: centred (only the launch prefix)"
lacks "$(cat "$REPO/bin/kawa-menu")" "x-margin"
case_ "its key again: closed, no second one; pressed fast (dwl repeats no held key that opens it): every press counts — open after an odd number, closed after an even one"
fresh; answer hang; kawa-menu --launcher & bg=$!; waitfor "$FZ/hang.1"
kawa-menu --launcher; wait "$bg"
open_fz && _no "still open" || _ok; eq "$(fz_n)" 1 "no second launcher"
for _ in {1..10}; do answer hang; done; bad=""
for i in {1..7}; do
  setsid -f kawa-menu --launcher </dev/null >/dev/null 2>&1
  for _ in {1..100}; do want=$((i % 2)); got=0; open_fz && got=1; ((got == want)) && break; sleep 0.01; done
  ((got == want)) || bad+=" press $i: open $got;"
done
eq "${bad:-ok}" ok
open_fz && kill "$(cat "$FZ/hang.$(fz_n)")"
case_ "lit while open: kawa-launcher.open (kawa-menu's pid), gone however it ends"
fresh; answer hang; kawa-menu --launcher & bg=$!; waitfor "$FZ/hang.1"; sleep 0.1
[[ $(cat "$R/kawa-launcher.open" 2>/dev/null) == "$bg" ]] && _ok || _no "no marker with its pid"
kill "$(cat "$FZ/hang.1")"; wait "$bg"; [[ -e $R/kawa-launcher.open ]] && _no "the marker stayed" || _ok
case_ "the torii clicked while it is open: that click closed it (outside) — the click's own call does not reopen it; the next click opens it, however soon"
fresh; answer hang hang; press; kawa-menu --launcher & bg=$!; waitfor "$FZ/hang.1"
press; kill "$(cat "$FZ/hang.1")"                  # (dwl: the press written, then the menu loses the keyboard)
kawa-menu --launcher; wait "$bg"
open_fz && _no "reopened by the click that closed it" || _ok; eq "$(fz_n)" 1
press; kawa-menu --launcher & bg=$!; waitfor "$FZ/hang.2" && _ok || _no "the next click did not open it"
kill "$(cat "$FZ/hang.2" 2>/dev/null)" 2>/dev/null; wait "$bg"
case_ "a fast clicker: 16 clicks on the torii, 80–150 ms apart, the click outside arriving before or after the click's own call — open after each odd click, closed after each even one, lit exactly while open"
fresh; for _ in {1..20}; do answer hang; done; bad=""; RANDOM=7
for i in {1..16}; do
  press
  if open_fz && ((RANDOM % 2)); then kill "$(cat "$FZ/hang.$(fz_n)")"; fi   # (the press took its keyboard first)
  setsid -f kawa-menu --launcher </dev/null >/dev/null 2>&1
  sleep "0.$((80 + RANDOM % 70))"
  # (the state looked at until it is the one wanted — 1.5 s, for a busy machine)
  want=$((i % 2))
  for _ in {1..75}; do
    got=0; open_fz && got=1; lit=0; [[ -e $R/kawa-launcher.open ]] && lit=1
    [[ $got == "$want" && $lit == "$want" ]] && break; sleep 0.02
  done
  [[ $got == "$want" && $lit == "$want" ]] || bad+=" click $i: open $got lit $lit;"
done
eq "${bad:-ok}" ok
open_fz && kill "$(cat "$FZ/hang.$(fz_n)")"
case_ "a plain fuzzel (a passphrase) holds fuzzel's lock: the launcher does not open; once it is gone, it does"
fresh; exec 7>>"$R/fuzzel-$WAYLAND_DISPLAY.lock"; flock 7
rc 1 kawa-menu --launcher; eq "$(fz_n)" 0
exec 7>&-; answer esc; kawa-menu --launcher; eq "$(fz_n)" 1
case_ "a record left by a launcher killed mid-way, its pid now someone else's, or garbage: ignored, nothing killed"
fresh; sleep 30 & other=$!
printf '%s open - -\n' "$other" >"$R/kawa-launcher.state"
answer esc; kawa-menu --launcher; eq "$(fz_n)" 1 "it opened"
[[ -e /proc/$other ]] && _ok || _no "an unrelated process was killed"; kill "$other"
t=0; for junk in "-1 open x y z" "garbage" "" $'\x01\x02 x y'; do
  printf '%s\n' "$junk" >"$R/kawa-launcher.state"; answer esc; at $((t += 1000)) kawa-menu --launcher
done
eq "$(fz_n)" 5 "it opened every time"

done_
