#!/usr/bin/env bash
# tests/look/test_term.sh — kawa-term CMD [ARG…]: CMD in a new terminal window, through the
# foot server (footclient) or, with that server down, a foot of its own. footclient and
# foot are stand-ins that keep their arguments exactly and the folder they were started in.
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

case_ "the server down: a foot of its own, the same command and arguments"
setup; : >"$TMP/down"
err=$(kawa-term "${odd[@]}" 2>&1); r=$?
eq "$r" 0
args_eq foot 1 -- "${odd[@]}"
eq "$err" "" "footclient's complaint is not shown"
FOOT_EXIT=3 kawa-term false; r=$?
eq "$r" 3 "a standalone foot's own status comes back"

case_ "footclient not installed: foot"
setup; hide footclient
rc 0 kawa-term htop
args_eq foot 1 -- htop

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
  : >"$TMP/down"
  ( cd "$TMP/$d" && kawa-term yazi )
  eq "$(cat "$TMP/foot.pwd")" "$TMP/$d" "[$d] a foot of its own"
done

case_ "from a service (PATH without ~/.local/bin): the helpers are found; never added twice"
setup; : >"$TMP/down"
PATH="$STUBS:/usr/bin:/bin" "$REPO/bin/kawa-term" yazi
eq "$(cut -d: -f1 "$TMP/foot.path")" "$HOME/.local/bin"
setup; : >"$TMP/down"
PATH="$HOME/.local/bin:$PATH" kawa-term yazi
eq "$(tr ':' '\n' <"$TMP/foot.path" | grep -cx "$HOME/.local/bin")" 1
setup; : >"$TMP/down"
mkdir -p "$TMP/my home"; HOME="$TMP/my home" PATH="$STUBS:$REPO/bin:/usr/bin:/bin" kawa-term yazi
eq "$(cut -d: -f1 "$TMP/foot.path")" "$TMP/my home/.local/bin" "a home with a space"

case_ "--help shows how it is used, and opens nothing"
setup
out=$(kawa-term --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-term CMD [ARG…]"
eq "$(ncalls footclient)$(ncalls foot)" 00

done_
