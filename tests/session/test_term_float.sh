#!/usr/bin/env bash
# tests/session/test_term_float.sh — kawa-term --float, the small floating terminal window every popup of
# the desktop opens in (books, notes, clipboard, wallpaper, network, system, file dialog): the
# terminal server's window (never a second terminal beside it), one at a time with --once
# — its key again closes it (a dialog's never) — and its exit status (0 opened · 1 no window · 2 misuse · 3
# toggled closed, or closed a moment ago).
# footclient and foot are stand-ins: "open" runs the window's command as the terminal would.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

# term NAME open|fail|closed — footclient/foot: open runs the window's command (and returns
# its status, as footclient does); fail opens nothing (no server); closed opens the window,
# then is gone with an error (Super+Q, or Esc in a menu that exits non-zero). footclient told
# to end (TERM) ends its window: what runs in it gets the hang-up (foot's own status, 220)
WINDOW='setsid "$@" & c=$!
trap "kill -HUP -$c 2>/dev/null; exit 220" TERM
wait $c; exit $?'                                   # (a terminal's window: a session of its own)
term() {
  local run='while [ "$1" != -- ]; do shift; done; shift'
  case $2 in
    open)   stub "$1" "$run
$WINDOW" ;;
    fail)   stub "$1" 'exit 1' ;;
    closed) stub "$1" "$run"'; "$@"; exit 1' ;;
  esac
}
setup() { session_sandbox; term footclient open; term foot open; RUN=$XDG_RUNTIME_DIR; }
# a Turkish locale from glibc's own definition, built meanwhile, outside the per-case sandboxes
LOCDIR=$(mktemp -d "${TMPDIR:-/tmp}/kawa-test-loc.XXXXXX")
localedef -i tr_TR -f UTF-8 "$LOCDIR/tr_TR.UTF-8" >/dev/null 2>&1 & LOCPID=$!
# mkinside — "inside", what runs in the window: logs its arguments and whether it holds the
# --once lock (fd 9); waits for the file $KF_WAIT if set (the window stays open), exits $KF_RC
mkinside() { stub inside '[ -e /proc/self/fd/9 ] && echo "inside holds fd 9" >>"'"$CALLS"'"; [ -n "$KF_WAIT" ] && while [ ! -e "$KF_WAIT" ]; do [ -d "${KF_WAIT%/*}" ] || exit 1; /bin/sleep 0.05; done; exit "${KF_RC:-0}"'; }

case_ "the terminal server opens it: app-id float, the title, the size; the command runs inside; exit 0"
setup; mkinside
rc 0 kawa-term --float books 100x27 -- inside --tui "a b" 'c"d'
called '^footclient -a float -T books -W 100x27 -- sh -c : >"\$1"; m=\$1; shift; "\$@"; r=\$\?; echo ended >"\$m"; exit \$r kawa-term .*/kawa-term\.[A-Za-z0-9]+ inside --tui a b c"d$'
called '^inside --tui a b c"d$'; not_called '^foot '
m=("$RUN"/kawa-term.*); [[ ! -e ${m[0]} ]] && _ok || _no "its mark is left behind: ${m[*]}"
case_ "the command's own exit status is not kawa-term --float's: it opened (exit 0)"
setup; mkinside; KF_RC=5 rc 0 kawa-term --float t 80x25 -- inside; not_called '^foot '
case_ "--locked-title: the title stays what it was given"
setup; mkinside; rc 0 kawa-term --float --locked-title "pick a file" 100x31 -- inside
called '^footclient -a float -T pick a file -W 100x31 -o locked-title=yes -- '
case_ "no terminal server (footclient opens nothing): no window, exit 1 — never a second terminal (the session keeps the server; repair restarts it)"
setup; mkinside; term footclient fail; rc 1 kawa-term --float --locked-title notes 80x25 -- inside x
not_called '^foot '; not_called '^inside'
case_ "the window was opened and then closed (Super+Q): never a second one"
setup; mkinside; term footclient closed; rc 0 kawa-term --float books 100x27 -- inside; not_called '^foot '
eq "$(grep -c '^inside' "$CALLS")" 1
case_ "the terminal server not listening yet (just after login, or being started again): footclient asked again until it opens — one window, exit 0 (the file dialog's \"no terminal window opened\")"
setup; mkinside; export WAYLAND_DISPLAY=wayland-test
stub footclient 'n=$(cat "$TMP/tries" 2>/dev/null || echo 0); echo $((n + 1)) >"$TMP/tries"
[ "$n" -lt 2 ] && { echo "failed to connect (is foot --server running?)" >&2; exit 220; }
while [ "$1" != -- ]; do shift; done; shift; exec setsid -w "$@"'
rc 0 kawa-term --float --dialog --locked-title "open file" 100x31 -- inside x
eq "$(grep -c '^footclient' "$CALLS")" 3 "asked three times"; eq "$(grep -c '^inside' "$CALLS")" 1 "one window"
case_ "… but a status of what ran in the window (or a window that was closed) is never asked again"
setup; mkinside; export WAYLAND_DISPLAY=wayland-test
stub footclient 'while [ "$1" != -- ]; do shift; done; shift; "$@"; exit 220'
rc 0 kawa-term --float --dialog t 100x31 -- inside; eq "$(grep -c '^footclient' "$CALLS")" 1
case_ "… and without a display (not in a desktop session) nothing is waited for: exit 1 at once"
setup; mkinside; unset WAYLAND_DISPLAY; stub footclient 'exit 220'
rc 1 kawa-term --float --dialog t 100x31 -- inside; eq "$(grep -c '^footclient' "$CALLS")" 1
case_ "no terminal installed at all (command not found): exit 1, quiet"
setup; stub footclient 'echo "footclient: not found" >&2; exit 127'; mkinside
eq "$(kawa-term --float books 100x27 -- inside 2>&1; echo "rc=$?")" "rc=1"

# inside_up — how many "inside" run now (what runs in a window); opened NAME — wait until
# "inside NAME" has started
inside_up() { /usr/bin/pgrep -fc "^/bin/sh $STUBS/inside " || true; }
opened() { for ((i = 0; i < 500; i++)); do grep -q "^inside $1" "$CALLS" && return; nap 0.01; done; }
press() { : >"$RUN/dwl-pointer.new"; mv -f "$RUN/dwl-pointer.new" "$RUN/dwl-pointer"; }   # (dwl: a press on the bar)
outside() {   # outside NAME — the window of "inside NAME" closed from outside: its group hung up
  local p g; p=$(/usr/bin/pgrep -f "^/bin/sh $STUBS/inside $1") && g=$(/usr/bin/ps -o pgid= -p "$p") && kill -HUP -- "-${g// /}"
}
case_ "--once: one window at a time — its key again closes it at once (exit 3; the call that opened it: 0), what ran in it hung up, its mark gone; another name opens its own"
setup; mkinside; export KF_WAIT=$TMP/close
kawa-term --float --once books books 100x27 -- inside first & p=$!; opened first
rc 0 kawa-term --float --once notes notes 80x25 -- true "another name: its own window"
not_called 'inside holds fd 9'
eq "$(cat "$RUN/kawa-term-books.open" 2>/dev/null)" "$p" "its mark: its pid"
rc 3 kawa-term --float --once books books 100x27 -- inside second
not_called '^inside second'
[[ -e $RUN/kawa-term-books.open ]] && _no "the mark stayed (the bar's button lit)" || _ok
for ((i = 0; i < 300; i++)); do kill -0 "$p" 2>/dev/null || break; nap 0.01; done
kill -0 "$p" 2>/dev/null && { _no "the open one did not close"; : >"$KF_WAIT"; } || _ok
wait "$p"; eq "$?" 0 "the call that opened it: it opened (and is closed now)"
eq "$(inside_up)" 0 "what ran in the window was hung up"
unset KF_WAIT
case_ "--once: pressed as fast as you like (calls 20 ms apart, while the window is still on its way up): every press counts — an odd number leaves one window open, an even one none, lit exactly then"
for n in 1 2 3 4 5 8 9; do
  setup; mkinside; export KF_WAIT=$TMP/close
  stub footclient 'while [ "$1" != -- ]; do shift; done; shift
/bin/sleep 0.15'"
$WINDOW"                                          # (a window that takes its time to come up)
  pids=()
  for ((i = 1; i <= n; i++)); do kawa-term --float --once books books 100x27 -- inside "n$i" & pids+=($!); nap 0.02; done
  for ((t = 0; t < 100; t++)); do   # (settled: as it ends up, within 5 s)
    up=0; for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && ((up++)); done
    lit=0; [[ -e $RUN/kawa-term-books.open ]] && lit=1
    got="$up $(inside_up) $lit"; [[ $got == "$((n % 2)) $((n % 2)) $((n % 2))" ]] && break; nap 0.05
  done
  eq "$got" "$((n % 2)) $((n % 2)) $((n % 2))" "$n presses: [calls waiting, what runs in windows, lit]"
  : >"$KF_WAIT"; wait "${pids[@]}" 2>/dev/null; unset KF_WAIT
done
case_ "--once: the click on its bar button that just closed it (by clicking outside) does not open it again; the next click, or a key, does"
setup; mkinside; export KF_WAIT=$TMP/close; press
kawa-term --float --once books books 100x27 -- inside third & p=$!; opened third
nap 0.05; press; outside third; wait "$p"   # (the press closes the popup)
rc 3 kawa-term --float --once books books 100x27 -- inside fourth; not_called '^inside fourth'
unset KF_WAIT
rc 0 kawa-term --float --once books books 100x27 -- inside fifth; called '^inside fifth'
case_ "--once: … but only that click, and only for a moment: a second later its key opens it"
setup; mkinside; export KF_WAIT=$TMP/close; press
kawa-term --float --once books books 100x27 -- inside a & p=$!; opened a
nap 0.05; press; outside a; wait "$p"; unset KF_WAIT
touch -d '2 seconds ago' "$RUN/kawa-term-books.closed"
rc 0 kawa-term --float --once books books 100x27 -- inside b; called '^inside b'
case_ "--once: closed from outside with no press on the bar since it opened (another window opened, Super+Q): its key opens it again at once"
setup; mkinside; export KF_WAIT=$TMP/close; press; touch -d '1 second ago' "$RUN/dwl-pointer"
kawa-term --float --once books books 100x27 -- inside c & p=$!; opened c
outside c; wait "$p"; unset KF_WAIT
[[ ! -e $RUN/kawa-term-books.closed ]] && _ok || _no "marked closed by a click"
rc 0 kawa-term --float --once books books 100x27 -- inside d; called '^inside d'
case_ "--once: a window that ended by itself (Esc) opens again at once with the same key"
setup; mkinside
rc 0 kawa-term --float --once books books 100x27 -- inside fifth
[[ ! -e $RUN/kawa-term-books.closed ]] && _ok || _no "a window that ended by itself is marked closed from outside"
rc 0 kawa-term --float --once books books 100x27 -- inside sixth; called '^inside sixth'
KF_RC=1 rc 0 kawa-term --float --once books books 100x27 -- inside seventh   # (Esc in a menu: its own non-zero end)
rc 0 kawa-term --float --once books books 100x27 -- inside eighth; called '^inside eighth'

case_ "--once --dialog: its key again leaves it open (exit 3) — a job in it is never cut short; app-id kawa-dialog"
setup; mkinside; export KF_WAIT=$TMP/close
kawa-term --float --once job --dialog job 100x27 -- inside job & p=$!
for ((i = 0; i < 500; i++)); do grep -q '^inside job' "$CALLS" && break; nap 0.01; done
called '^footclient -a kawa-dialog -T job -W 100x27 -- '
rc 3 kawa-term --float --once job --dialog job 100x27 -- inside again; not_called '^inside again'
nap 0.3; kill -0 "$p" 2>/dev/null && _ok || _no "the dialog's key again closed it"
: >"$KF_WAIT"; wait "$p"; eq "$?" 0 "it ran to its end"; unset KF_WAIT

case_ "--once after a run that was killed (its lock file left behind): opens as usual"
setup; mkinside; : >"$RUN/kawa-term-books.lock"; rc 0 kawa-term --float --once books books 100x27 -- inside
called '^inside'

case_ "misuse: exit 2, no window (and never a hang)"
setup; mkinside
for args in "" "books" "books 100x27" "books 100x27 --" "books 100x27 inside" "books 100 -- inside" "books 100x -- inside" \
            "books x27 -- inside" "books 100x27x2 -- inside" "books -1x5 -- inside" "--bogus books 100x27 -- inside" \
            "--once" "--once books" "--once Books books 100x27 -- inside" "--once ../x books 100x27 -- inside" \
            "--once  books 100x27 -- inside"; do
  # shellcheck disable=SC2086  # the words are the arguments
  rc 2 timeout 10 kawa-term --float $args
done
rc 2 timeout 10 kawa-term --float --once "" books 100x27 -- inside
rc 2 timeout 10 kawa-term --float "" 100x27 -- inside
not_called '^footclient'; not_called '^inside'
case_ "--help: what it does, exit 0"
has "$(kawa-term --help)" "--once NAME"; rc 0 kawa-term --help

case_ "odd titles and arguments reach the window as they are, never run"
setup; mkinside
# (the probe names a file in this test's own folder: should it ever run, nothing outside it is touched)
P=$TMP/pwned
rc 0 kawa-term --float "-x \$(touch $P) \`touch $P\` \"q\" ج 日本" 80x25 -- inside "\$(touch $P)" '' ' sp '
called "^footclient -a float -T -x \\\$\\(touch .*pwned\\) \`touch .*pwned\` \"q\" ج 日本 -W 80x25 "
called "^inside \\\$\\(touch .*pwned\\)   sp \$"
[[ ! -e $P ]] && _ok || _no "a title ran as a command"
case_ "a runtime folder with a space; none at all (exit 1, no window)"
setup; mkinside; mkdir -p "$TMP/run time"; XDG_RUNTIME_DIR="$TMP/run time" rc 0 kawa-term --float --once books books 100x27 -- inside
[[ -e "$TMP/run time/kawa-term-books.lock" ]] && _ok || _no "the lock is not in the runtime folder"
reset_calls; rc 1 env -u XDG_RUNTIME_DIR kawa-term --float books 100x27 -- inside; not_called '^footclient'

case_ "a Turkish locale (where [a-z] leaves out i): the clipboard, the what-changed (diff) and the books windows still open"
wait "$LOCPID" 2>/dev/null
for name in clipboard diff books; do
  setup; mkinside
  LOCPATH=$LOCDIR LC_ALL=tr_TR.UTF-8 kawa-term --float --once "$name" "$name" 76x25 -- inside "$name" 2>/dev/null; eq "$?" 0 "--once $name"
  called "^inside $name$"
done

case_ "every popup in the desktop opens at an even width and an odd height (centred to the pixel)"
while IFS= read -r ln; do
  sz=$(grep -oE '\b[0-9]+x[0-9]+\b' <<<"$ln" | head -n1)
  [[ $sz =~ ^([0-9]+)x([0-9]+)$ ]] || continue
  ((BASH_REMATCH[1] % 2 == 0 && BASH_REMATCH[2] % 2 == 1)) && _ok || _no "$sz: $ln"
done < <(grep -rhE '(kawa-term --float|\<hold [a-z]+ ")[^#]*\<[0-9]+x[0-9]+\>' "$REPO/bin" "$REPO/system")
eq "$(grep -rhoE 'kawa-term --float (--locked-title )?--once [^ ]+' "$REPO/bin" "$REPO/system" | awk '{print $NF}' | grep -vE '^("\$name"|[a-z0-9-]+)$')" "" \
  "every --once name a plain word"

rm -rf "$LOCDIR"
done_
