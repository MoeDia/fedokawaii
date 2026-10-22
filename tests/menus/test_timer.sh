#!/usr/bin/env bash
# tests/menus/test_timer.sh — kawa-timer (a click on the bar's time): the menu, a timer and a
# stopwatch in $XDG_RUNTIME_DIR, the bar's module drawing them (a waybar restart included), the
# end's one critical notice with the bell and its chime, cancel. notify-send and pw-play are
# stand-ins; the bar runs for real, read through a pipe.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
# shellcheck source=/dev/null
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

BARS=() NB=0
setup() { menus_sandbox; stub notify-send; stub pw-play; }
st() { cat "$XDG_RUNTIME_DIR/kawa-timer" 2>/dev/null; }
rings() { pgrep -u "$UID" -f '(^|/)kawa-timer ring [0-9]+$' | grep -c .; }
bar_up() {   # bar_up [timer] — a bar's clock (or, with timer, its timer cell) of its own (as waybar starts one per monitor), its lines in $TMP/bar.N (N: 0, 1, …)
  local n=$NB; NB=$((NB + 1)); : >"$TMP/bar.$n"
  kawa-timer bar "$@" >>"$TMP/bar.$n" 2>&1 & BARS+=($!)
  for _ in {1..50}; do [[ -s $TMP/bar.$n ]] && return; sleep 0.02; done
}
bars_down() { local p; for p in "${BARS[@]}"; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; BARS=(); }
on_exit 'bars_down; pkill -u "$UID" -f "(^|/)kawa-timer ring [0-9]+$" 2>/dev/null'
last() { tail -n1 "$TMP/bar.${1:-0}"; }
settles() {   # settles MS FILE PATTERN — FILE's last line matches PATTERN (a bash regex) within MS ms
  local t0=${EPOCHREALTIME/./}
  while (( (${EPOCHREALTIME/./} - t0) / 1000 < $1 )); do
    [[ $(tail -n1 "$2") =~ $3 ]] && return 0; sleep 0.01
  done
  return 1
}
within() {   # within MS FILE TEXT — TEXT shows in a line of FILE within MS milliseconds
  local t0=${EPOCHREALTIME/./}
  while (( (${EPOCHREALTIME/./} - t0) / 1000 < $1 )); do
    grep -qF -- "$3" "$2" && return 0; sleep 0.01
  done
  return 1
}

# ── the menu ─────────────────────────────────────────────────────────────────────────
case_ "the clock's menu: a heading, 5 · 10 · 25 · 45 · 60 min and a stopwatch, under the bar; no cancel while none runs"
setup; answer esc; rc 0 kawa-timer
rows=$(fz_rows)
eq "$(sed -n 1p <<<"$rows")" "part	時	timer	" "the heading: 時 timer, nothing running at its end"
eq "$(sed -n '2,6p' <<<"$rows" | tr '\n' '|')" "row	$ICON_HOURGLASS	 5 min|row	$ICON_HOURGLASS	10 min|row	$ICON_HOURGLASS	25 min|row	$ICON_HOURGLASS	45 min|row	$ICON_HOURGLASS	60 min|" "a row a length, the figures right-aligned"
eq "$(sed -n 7p <<<"$rows")" "row	$ICON_HOURGLASS	stopwatch"
lacks "$rows" cancel; eq "$(wc -l <<<"$rows")" 7
eq "$(fz_arg drop)" set "a dropdown, as the calendar"; eq "$(fz_arg select)" 1 "on 5 min, not the heading"
eq "$(fz_arg width)" "" "sized to its content"
fits
case_ "Esc, a click outside: nothing set"
for a in esc lost; do setup; answer "$a"; rc 0 kawa-timer; eq "$(st)" ""; done

case_ "25 min picked: the state says when it ends, one waiter left behind, and the menu offers cancel"
setup; answer "pick 25 min"; t0=$EPOCHSECONDS; kawa-timer
read -r k end m set <<<"$(st)"
eq "$k" timer; eq "$m" 25
(( end - t0 >= 1500 && end - t0 <= 1501 )) && _ok || _no "ends $((end - t0)) s from now, not 1500"
[[ $set =~ ^[01][0-9]:[0-5][0-9]\ [AP]M$ ]] && _ok || _no "set at [$set], not as the bar's clock writes it"
eq "$(rings)" 1 "one waiter"
answer esc; kawa-timer; has "$(fz_rows)" "row	$ICON_CROSS	cancel the timer"
[[ $(fz_rows | sed -n 1p) =~ ^part$'\t'時$'\t'timer$'\t'2[45]:[0-5][0-9]\ left$ ]] && _ok || _no "the running timer at the heading's end: $(fz_rows | sed -n 1p)"
case_ "another timer takes the first one's place (one waiter, the new end)"
answer "pick 5 min"; kawa-timer
eq "$(rings)" 1; read -r _ end2 m _ <<<"$(st)"; eq "$m" 5; ((end2 < end)) && _ok || _no "the 25 min one still stands"
case_ "cancel from the menu: the state and the waiter gone, quietly (a timer has nothing to tell)"
answer "pick cancel"; kawa-timer
eq "$(st)" ""; eq "$(rings)" 0; not_called '^notify-send'

# ── the bar ──────────────────────────────────────────────────────────────────────────
case_ "the bar: the clock the time alone, always; the timer a cell of its own — empty while none runs, at once beside the clock when one is set (its colour the class's: style.css)"
setup; bar_up; bar_up timer
[[ $(last) =~ ^\{\"text\":\"[01][0-9]:[0-5][0-9]:[0-5][0-9]\ [AP]M\"\}$ ]] && _ok || _no "the time: $(last)"
eq "$(last 1)" '{"text":""}' "no timer: an empty cell (waybar hides it)"
kawa-timer start 10
within 300 "$TMP/bar.1" '"class":"timer"' && _ok || _no "no timer on the bar 0.3 s after it was set: $(last 1)"
# (8 px from the hourglass's ink to the figures': ICON_BAR_HOURGLASS, no space; 10:00, or 09:59
# should a second turn meanwhile)
[[ $(last 1) == '{"text":"'"${ICON_BAR_HOURGLASS}"@(10:00|09:59)'","class":"timer"}' ]] && _ok || _no "the hourglass and the time left: $(last 1)"
within 2500 "$TMP/bar.1" "${ICON_BAR_HOURGLASS}09:59" && _ok || _no "the second after: $(last 1)"
[[ $(last) =~ ^\{\"text\":\"[01][0-9]:[0-5][0-9]:[0-5][0-9]\ [AP]M\"\}$ ]] && _ok || _no "the clock keeps to the time: $(last)"
case_ "two monitors, two bars: both draw it, both at once"
bar_up timer; within 300 "$TMP/bar.2" "${ICON_BAR_HOURGLASS}09:5" && _ok || _no "the second bar: $(last 2)"
case_ "waybar restarted: the new bar reads the timer from the runtime folder"
bars_down; bar_up timer; has "$(last 3)" "\"class\":\"timer\"" ; has "$(last 3)" "${ICON_BAR_HOURGLASS}09:5"
eq "$(find "$XDG_RUNTIME_DIR" -name 'kawa-bar.wake.*' | wc -l)" 1 "the killed bars' fifos gone, the live one's there"
case_ "a stopwatch: from 0:00, counting up, the stopwatch's class (asagi); cancel says where it stood"
kawa-timer stopwatch; eq "$(rings)" 0 "the timer's waiter gone with it"
within 300 "$TMP/bar.3" "{\"text\":\"${ICON_BAR_HOURGLASS}00:00\",\"class\":\"stopwatch\"}" && _ok || _no "$(last 3)"
within 3000 "$TMP/bar.3" "${ICON_BAR_HOURGLASS}00:01" || within 1 "$TMP/bar.3" "${ICON_BAR_HOURGLASS}00:02" && _ok || _no "a second on: $(last 3)"
kawa-timer cancel
settles 300 "$TMP/bar.3" '^\{"text":""\}$' && _ok || _no "still on the bar: $(last 3)"
called "^notify-send -a desktop -- $ICON_HOURGLASS  stopwatch stopped at 00:0[1-9]$"
case_ "a stopwatch past an hour: H:MM:SS"
printf 'stopwatch %s\n' $((EPOCHSECONDS - 3723)) >"$XDG_RUNTIME_DIR/kawa-timer"
within 1500 "$TMP/bar.3" "${ICON_BAR_HOURGLASS}1:02:0" && _ok || _no "$(last 3)"
answer esc; kawa-timer
[[ $(fz_rows | sed -n 1p) =~ ^part$'\t'時$'\t'timer$'\t'stopwatch\ 1:02:0[0-9]$ ]] && _ok || _no "the stopwatch at the menu's heading: $(fz_rows | sed -n 1p)"
has "$(fz_rows)" "row	$ICON_CROSS	cancel the stopwatch"
bars_down
rc 2 kawa-timer bar clock; rc 2 kawa-timer bar timer x

# ── the end ──────────────────────────────────────────────────────────────────────────
case_ "the end: one critical notice with the bell, a chime through pw-play, the state gone"
setup; e=$((EPOCHSECONDS + 1)); printf 'timer %s 25 02:05 PM\n' "$e" >"$XDG_RUNTIME_DIR/kawa-timer"
t0=${EPOCHREALTIME/./}; kawa-timer ring "$e"; sleep 0.1
(( (${EPOCHREALTIME/./} - t0) / 1000 <= 2100 )) && _ok || _no "it rang late"
called "^notify-send -a desktop -u critical -- $ICON_BELL  time is up the 25 min timer set at 02:05 PM has ended$"
eq "$(grep -c '^notify-send' "$CALLS")" 1 "exactly one notice"
called "^pw-play $XDG_RUNTIME_DIR/kawa-timer.wav$"
eq "$(st)" ""
python3 -I -c 'import wave, sys; w = wave.open(sys.argv[1]); p = w.getparams()
sys.exit(0 if (p.nchannels, p.sampwidth, p.framerate) == (1, 1, 8000) and 0.4 < p.nframes / 8000 < 0.5 else 1)' \
  "$XDG_RUNTIME_DIR/kawa-timer.wav" && _ok || _no "the chime is not a 0.46 s 8-bit WAV"
case_ "cancelled, or replaced, before the end: the waiter says nothing"
setup; e=$((EPOCHSECONDS + 1)); printf 'timer %s 5 02:05 PM\n' $((e + 600)) >"$XDG_RUNTIME_DIR/kawa-timer"
kawa-timer ring "$e"; not_called '^notify-send'; not_called '^pw-play'
rm -f "$XDG_RUNTIME_DIR/kawa-timer"; kawa-timer ring "$e"; not_called '^notify-send'

# ── the bar's wiring ─────────────────────────────────────────────────────────────────
case_ "waybar: the time's click is the timer, the date's and the day's the calendar; the timer a cell of its own, first after the music, its click the timer's menu"
wb() { python3 -B -c 'import json,sys; sys.path.insert(0,sys.argv[1]); import parsecheck as p
c=json.loads(p.strip_jsonc(open(sys.argv[2]).read())); print(eval(sys.argv[3]))' "$REPO/tests/static" "$REPO/configs/home/.config/waybar/config.jsonc" "$1"; }
eq "$(wb 'c["custom/time"]["on-click"]')" "setsid -f kawa-timer"
eq "$(wb 'c["custom/date"]["on-click"]')" "setsid -f kawa-calendar"; eq "$(wb 'c["custom/day"]["on-click"]')" "setsid -f kawa-calendar"
eq "$(wb '" ".join(c["group/when"]["modules"])')" "custom/wing-left custom/date custom/day custom/time custom/wing-right" "the clock and the music's wings, one scroll"
eq "$(wb 'c["custom/time"]["exec"]')" "kawa-timer bar"; eq "$(wb 'c["custom/timer"]["exec"]')" "kawa-timer bar timer"
eq "$(wb 'c["custom/timer"]["on-click"]')" "setsid -f kawa-timer"; eq "$(wb 'c["custom/timer"]["exec-on-event"]')" False
eq "$(wb '" ".join(c["group/status"]["modules"][:2])')" "custom/nowplaying custom/timer"
eq "$(wb 'c["custom/time"].get("interval", "")')" "" "one long-running script, no interval"

case_ "the bar's loop starts no process: each second is bash alone (no \$( ), no sleep)"
body=$(sed -n '/^bar() {/,/^}/p' "$REPO/bin/kawa-timer" | sed -n '/while :; do/,/^  done/p')
[[ -n $body ]] && _ok || _no "the loop was not found"
grep -qE '\$\([^(]' <<<"$body" && _no "a command substitution in the loop" || _ok   # (\$(( )) is arithmetic)
lacks "$body" 'sleep'; lacks "$body" '`'

case_ "misuse"
rc 2 kawa-timer start; rc 2 kawa-timer start 0; rc 2 kawa-timer start 1441; rc 2 kawa-timer start ten
rc 2 kawa-timer frobnicate; rc 0 kawa-timer --help
has "$(kawa-timer --help)" "kawa-timer start MINUTES"
rc 1 env -u XDG_RUNTIME_DIR kawa-timer bar
done_
