#!/usr/bin/env bash
# tests/session/test_crashnote.sh — kawa-crashnote at login: the session before ended in a crash
# of his own dwl → one critical notice with the time and the function it crashed in; a root
# dwl's crash (a test), another program's, or none → nothing; the first login only notes its time.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
B=$REPO/bin/kawa-crashnote
st=$HOME/.local/state/fedokawaii/session-start
me=$(id -u)
stub notify-send
stub coredumpctl 'case "$*" in
  *" list "*) printf "%s\n" "Mon 2026-10-26 12:22:19 +04   1325 '"$me"' '"$me"' SIGSEGV truncated /usr/local/bin/dwl 1.4M" "Tue 2026-10-27 02:23:38 +04 206075    0    0 SIGSEGV none      /usr/local/bin/dwl    -" ;;
  *" info "*) printf "%s\n" "Stack trace of thread 1325:" "                #0  0x000000000040b86f configurex11 (/usr/local/bin/dwl + 0xb86f)" ;;
esac'

case_ "the first login: its time noted, nothing said"
rc 0 "$B"; sleep 0.3
[[ -s $st ]] && _ok || _no "no session-start"
not_called "notify-send"

case_ "his dwl crashed since the last login: one critical notice, the time and where"
echo 1793000000 >"$st"
rc 0 "$B"; sleep 0.5
called "coredumpctl --no-pager --no-legend --since @1793000000 list /usr/local/bin/dwl"
called "notify-send -a desktop -u critical -- .*  the desktop restarted dwl crashed at 12:22, in configurex11: every window closed with it"
case_ "only a root (test) dwl crashed: nothing said"
: >"$CALLS"
stub coredumpctl 'case "$*" in *" list "*) echo "Tue 2026-10-27 02:23:38 +04 206075    0    0 SIGSEGV none /usr/local/bin/dwl -" ;; esac'
echo 1793000000 >"$st"
rc 0 "$B"; sleep 0.3
not_called "notify-send"
case_ "no crash: nothing said, the time moves on"
stub coredumpctl 'exit 0'
echo 1793000000 >"$st"
rc 0 "$B"; sleep 0.3
not_called "notify-send"
[[ $(cat "$st") != 1793000000 ]] && _ok || _no "session-start not updated"
done_
