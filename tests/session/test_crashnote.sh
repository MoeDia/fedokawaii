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

case_ "the first login: its time and its dwl's pid noted, nothing said"
rc 0 "$B" 4242; sleep 0.3
[[ $(cat "$st") =~ ^[0-9]+\ 4242$ ]] && _ok || _no "session-start: [$(cat "$st")]"
not_called "notify-send"

case_ "his session's dwl crashed (the pid the last login noted): one critical notice, the time and where"
echo "1793000000 1325" >"$st"
rc 0 "$B" 4242; sleep 0.5
called "coredumpctl --no-pager --no-legend --since @1793000000 list /usr/local/bin/dwl"
called "notify-send -a desktop -u critical -- .*  the desktop restarted dwl crashed at 12:22, in configurex11: every window closed with it"
case_ "a dwl of his own under another pid crashed (a headless run: the kit, the update's start check) — nothing said"
: >"$CALLS"
echo "1793000000 999" >"$st"
rc 0 "$B" 4242; sleep 0.3
not_called "notify-send"
case_ "a record from before the pid was kept (its time alone): nothing said, the new one with its pid"
: >"$CALLS"
echo 1793000000 >"$st"
rc 0 "$B" 4242; sleep 0.3
not_called "notify-send"
[[ $(cat "$st") =~ \ 4242$ ]] && _ok || _no "session-start: [$(cat "$st")]"
case_ "only a root (test) dwl crashed: nothing said"
: >"$CALLS"
stub coredumpctl 'case "$*" in *" list "*) echo "Tue 2026-10-27 02:23:38 +04 206075    0    0 SIGSEGV none /usr/local/bin/dwl -" ;; esac'
echo "1793000000 206075" >"$st"
rc 0 "$B" 4242; sleep 0.3
not_called "notify-send"
case_ "no crash: nothing said, the time moves on"
stub coredumpctl 'exit 0'
echo "1793000000 1325" >"$st"
rc 0 "$B" 4242; sleep 0.3
not_called "notify-send"
[[ $(cat "$st") != "1793000000 1325" ]] && _ok || _no "session-start not updated"
case_ "autostart hands it dwl's pid (its own parent's)"
grep -qx 'kawa-crashnote "$PPID" </dev/null >/dev/null 2>&1 &   # ($PPID: dwl, which runs this script)' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "autostart.sh does not pass \$PPID"
done_
