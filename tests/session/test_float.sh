#!/usr/bin/env bash
# tests/session/test_float.sh — kawa-float, the small floating terminal window every popup of
# the desktop opens in (books, notes, clipboard, wallpaper, network, system, file dialog): the
# terminal server's window (never a second terminal beside it), one at a time with --once
# — its key again closes it — and its exit status (0 opened · 1 no window · 2 misuse · 3
# toggled closed, or closed a moment ago).
# footclient and foot are stand-ins: "open" runs the window's command as the terminal would.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

# term NAME open|fail|closed — footclient/foot: open runs the window's command (and returns
# its status, as footclient does); fail opens nothing (no server); closed opens the window,
# then is gone with an error (Super+Q, or Esc in a menu that exits non-zero)
term() {
  local run='while [ "$1" != -- ]; do shift; done; shift'
  case $2 in
    open)   stub "$1" "$run"'; exec setsid -w "$@"' ;;   # (a terminal's window: a session of its own)
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
mkinside() { stub inside '[ -e /proc/self/fd/9 ] && echo "inside holds fd 9" >>"'"$CALLS"'"; [ -n "$KF_WAIT" ] && while [ ! -e "$KF_WAIT" ]; do /bin/sleep 0.05; done; exit "${KF_RC:-0}"'; }

case_ "the terminal server opens it: app-id float, the title, the size; the command runs inside; exit 0"
setup; mkinside
rc 0 kawa-float books 100x27 -- inside --tui "a b" 'c"d'
called '^footclient -a float -T books -W 100x27 -- sh -c : >"\$1"; \[ -n "\$2" \] && echo \$\$ >"\$2"; shift 2; exec "\$@" kawa-float .*/kawa-float\.[A-Za-z0-9]+  inside --tui a b c"d$'
called '^inside --tui a b c"d$'; not_called '^foot '
m=("$RUN"/kawa-float.*); [[ ! -e ${m[0]} ]] && _ok || _no "its mark is left behind: ${m[*]}"
case_ "the command's own exit status is not kawa-float's: it opened (exit 0)"
setup; mkinside; KF_RC=5 rc 0 kawa-float t 80x25 -- inside; not_called '^foot '
case_ "--locked-title: the title stays what it was given"
setup; mkinside; rc 0 kawa-float --locked-title "pick a file" 100x31 -- inside
called '^footclient -a float -T pick a file -W 100x31 -o locked-title=yes -- '
case_ "no terminal server (footclient opens nothing): no window, exit 1 — never a second terminal (the session keeps the server; repair restarts it)"
setup; mkinside; term footclient fail; rc 1 kawa-float --locked-title notes 80x25 -- inside x
not_called '^foot '; not_called '^inside'
case_ "the window was opened and then closed (Super+Q): never a second one"
setup; mkinside; term footclient closed; rc 0 kawa-float books 100x27 -- inside; not_called '^foot '
eq "$(grep -c '^inside' "$CALLS")" 1
case_ "no terminal installed at all (command not found): exit 1, quiet"
setup; stub footclient 'echo "footclient: not found" >&2; exit 127'; mkinside
eq "$(kawa-float books 100x27 -- inside 2>&1; echo "rc=$?")" "rc=1"

case_ "--once: one window at a time — its key again closes it (exit 3; held, within half a second, not), another name opens its own"
setup; mkinside; export KF_WAIT=$TMP/close
kawa-float --once books books 100x27 -- inside first & p=$!
for ((i = 0; i < 500; i++)); do grep -q '^inside first' "$CALLS" && break; nap 0.01; done
rc 0 kawa-float --once notes notes 80x25 -- true "another name: its own window"
not_called 'inside holds fd 9'
rc 3 kawa-float --once books books 100x27 -- inside held
kill -0 "$p" 2>/dev/null && _ok || _no "pressed again within half a second (the key held): it closed"
touch -d '1 second ago' "$RUN/kawa-float-books.pid"   # (open a while: now the key closes it)
rc 3 kawa-float --once books books 100x27 -- inside second
not_called '^inside second'
for ((i = 0; i < 300; i++)); do kill -0 "$p" 2>/dev/null || break; nap 0.01; done
kill -0 "$p" 2>/dev/null && { _no "the open one did not close"; : >"$KF_WAIT"; } || _ok
wait "$p"; unset KF_WAIT
case_ "--once: the click on its bar button that just closed it (by clicking outside) does not open it again"
rc 3 kawa-float --once books books 100x27 -- inside third; not_called '^inside third'
touch -d '2 seconds ago' "$RUN/kawa-float-books.closed"
rc 0 kawa-float --once books books 100x27 -- inside fourth; called '^inside fourth'

case_ "--once with the key held (20 calls at once): exactly one window"
setup; mkinside; export KF_WAIT=$TMP/close; pids=()
for i in $(seq 1 20); do kawa-float --once clipboard clipboard 76x25 -- inside "n$i" & pids+=($!); done
for ((i = 0; i < 3000; i++)); do  # (until all but the open one have given up)
  up=0; for p in "${pids[@]}"; do kill -0 "$p" 2>/dev/null && ((up++)); done; ((up <= 1)) && break; nap 0.01
done
: >"$KF_WAIT"; r3=0
for p in "${pids[@]}"; do wait "$p"; (($? == 3)) && ((r3++)); done
eq "$(grep -c '^inside' "$CALLS")" 1; eq "$r3" 19 "the other 19: already open"; unset KF_WAIT
case_ "--once after a run that was killed (its lock file left behind): opens as usual"
setup; mkinside; : >"$RUN/kawa-float-books.lock"; rc 0 kawa-float --once books books 100x27 -- inside
called '^inside'

case_ "misuse: exit 2, no window (and never a hang)"
setup; mkinside
for args in "" "books" "books 100x27" "books 100x27 --" "books 100x27 inside" "books 100 -- inside" "books 100x -- inside" \
            "books x27 -- inside" "books 100x27x2 -- inside" "books -1x5 -- inside" "--bogus books 100x27 -- inside" \
            "--once" "--once books" "--once Books books 100x27 -- inside" "--once ../x books 100x27 -- inside" \
            "--once  books 100x27 -- inside"; do
  # shellcheck disable=SC2086  # the words are the arguments
  rc 2 timeout 10 kawa-float $args
done
rc 2 timeout 10 kawa-float --once "" books 100x27 -- inside
rc 2 timeout 10 kawa-float "" 100x27 -- inside
not_called '^footclient'; not_called '^inside'
case_ "--help: what it does, exit 0"
has "$(kawa-float --help)" "--once NAME"; rc 0 kawa-float --help

case_ "odd titles and arguments reach the window as they are, never run"
setup; mkinside
# (the probe names a file in this test's own folder: should it ever run, nothing outside it is touched)
P=$TMP/pwned
rc 0 kawa-float "-x \$(touch $P) \`touch $P\` \"q\" ج 日本" 80x25 -- inside "\$(touch $P)" '' ' sp '
called "^footclient -a float -T -x \\\$\\(touch .*pwned\\) \`touch .*pwned\` \"q\" ج 日本 -W 80x25 "
called "^inside \\\$\\(touch .*pwned\\)   sp \$"
[[ ! -e $P ]] && _ok || _no "a title ran as a command"
case_ "a runtime folder with a space; none at all (exit 1, no window)"
setup; mkinside; mkdir -p "$TMP/run time"; XDG_RUNTIME_DIR="$TMP/run time" rc 0 kawa-float --once books books 100x27 -- inside
[[ -e "$TMP/run time/kawa-float-books.lock" ]] && _ok || _no "the lock is not in the runtime folder"
reset_calls; rc 1 env -u XDG_RUNTIME_DIR kawa-float books 100x27 -- inside; not_called '^footclient'

case_ "a Turkish locale (where [a-z] leaves out i): the clipboard, the what-changed (diff) and the books windows still open"
wait "$LOCPID" 2>/dev/null
for name in clipboard diff books; do
  setup; mkinside
  LOCPATH=$LOCDIR LC_ALL=tr_TR.UTF-8 kawa-float --once "$name" "$name" 76x25 -- inside "$name" 2>/dev/null; eq "$?" 0 "--once $name"
  called "^inside $name$"
done

case_ "every popup in the desktop opens at an even width and an odd height (centred to the pixel)"
while IFS= read -r ln; do
  sz=$(grep -oE '\b[0-9]+x[0-9]+\b' <<<"$ln" | head -n1)
  [[ $sz =~ ^([0-9]+)x([0-9]+)$ ]] || continue
  ((BASH_REMATCH[1] % 2 == 0 && BASH_REMATCH[2] % 2 == 1)) && _ok || _no "$sz: $ln"
done < <(grep -rhE '(kawa-float|\<hold [a-z]+ ")[^#]*\<[0-9]+x[0-9]+\>' "$REPO/bin" "$REPO/system")
eq "$(grep -rhoE 'kawa-float (--locked-title )?--once [^ ]+' "$REPO/bin" "$REPO/system" | awk '{print $NF}' | grep -vE '^("\$name"|[a-z0-9-]+)$')" "" \
  "every --once name a plain word"

rm -rf "$LOCDIR"
done_
