#!/usr/bin/env bash
# tests/look/test_term.sh — kawa-term CMD [ARG…]: CMD in a new terminal window, through the
# foot server (footclient) — the one way. footclient and foot are stand-ins that keep their
# arguments exactly and the folder they were started in.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"

setup() {
  look
  # the server's window: arguments and folder kept; $TMP/down: the server is not running
  argv footclient 'pwd >"$FAKE_TMP/client.pwd"; echo "$PATH" >"$FAKE_TMP/client.path"
[ -e "$FAKE_TMP/down" ] && { echo "failed to connect (is the server running?)" >&2; exit 220; }; exit 0'
  argv foot 'pwd >"$FAKE_TMP/foot.pwd"; echo "$PATH" >"$FAKE_TMP/foot.path"; exit "${FOOT_EXIT:-0}"'
}
odd=(yazi "" "two words" "-e" "--" "it's \"quoted\"" '$(touch pwned)' '`id`' $'line\nbreak' $'tab\there' "ü日本 العربية" "*")

setup
case_ "the server running: one footclient call, the command and every argument passed through intact"
rc 0 kawa-term "${odd[@]}"
args_eq footclient 1 -N -- "${odd[@]}"
eq "$(ncalls foot)" 0 "no second window"
[[ ! -e pwned && ! -e $TMP/pwned ]] && _ok || _no "an argument ran as a command"

case_ "the server down: footclient says so, its status comes back, no foot of its own"
setup; : >"$TMP/down"
err=$(kawa-term "${odd[@]}" 2>&1); r=$?
eq "$r" 220; has "$err" "is the server running?"
eq "$(ncalls foot)" 0

case_ "a command that fails inside the server's window still opens only one window"
setup
rc 0 kawa-term no-such-command --flag
eq "$(ncalls foot)" 0

case_ "no command: your shell (SHELL unset: bash fills it in from your account)"
setup
SHELL=/bin/zsh kawa-term
args_eq footclient 1 -N -- /bin/zsh
( unset SHELL; kawa-term )
args_eq footclient 2 -N -- "$(getent passwd "$(id -u)" | cut -d: -f7)"

case_ "started in a folder with an odd name: the window opens there"
for d in "my dir" "ü日本 العربية" "it's \"q\"" "-dash" $'new\nline' '$(x)'; do
  setup; mkdir -p "$TMP/$d"
  ( cd "$TMP/$d" && kawa-term yazi )
  eq "$(cat "$TMP/client.pwd")" "$TMP/$d" "[$d] through the server"
done

case_ "--help shows how it is used, and opens nothing"
setup
out=$(kawa-term --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-term CMD [ARG…]"
eq "$(ncalls footclient)$(ncalls foot)" 00

done_
