#!/usr/bin/env bash
# tests/content/test_foryou.sh — kawa-foryou: the few things only the owner can do (a cable to
# plug …), kept as files until done: a notice at every login that stays (critical, app foryou:
# mako's section makes its click the "done"), the first rows of Super+U's status. A click marks
# it done (the file goes); a notice closed another way only puts it away until the next login.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
B=$REPO/bin/kawa-foryou
d=$HOME/.local/state/fedokawaii/for-you

case_ "add, list, done: one file a thing, its first line the title"
rc 0 "$B" add cable "connect a second cable" "the card's DisplayPort to the monitor's"
rc 0 "$B" add other-thing "something else" "words"
eq "$(cat "$d/cable")" $'connect a second cable\nthe card\'s DisplayPort to the monitor\'s'
eq "$("$B" list | sort)" $'connect a second cable\nsomething else'
rc 0 "$B" done other-thing
eq "$("$B" list)" "connect a second cable"
rc 1 "$B" done other-thing
rc 2 "$B" add "Bad Name" t w
rc 2 "$B" add only-two
rc 2 "$B"

case_ "show: a critical notice per thing, the user icon and two spaces, the words; a click (default) removes it"
stub notify-send 'echo default'
"$B" show; sleep 0.5
called "notify-send -a foryou -u critical -A default=done --wait -- .*  connect a second cable the card's DisplayPort"
[[ -e $d/cable ]] && _no "a click left the file" || _ok

case_ "show: closed another way (no action back) → kept for the next login"
"$B" add cable "connect a second cable" "words"
stub notify-send 'exit 0'
"$B" show; sleep 0.5
[[ -e $d/cable ]] && _ok || _no "closing it removed it"

case_ "nothing to do: show and list say nothing"
"$B" done cable
: >"$CALLS"
"$B" show; sleep 0.3
not_called "notify-send"
eq "$("$B" list)" ""
done_
