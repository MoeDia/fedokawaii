#!/usr/bin/env bash
# tests/session/test_autostart.sh — ~/.config/dwl/autostart.sh, what dwl runs at login: what it
# starts and in which order, that a crashed helper comes back (and one that keeps crashing
# gives up with a notice), that nothing outlives the session (logged out, or dwl crashed),
# and that a missing, slow or crashing program never holds back the rest.
# It runs as dwl runs it: a session of its own (setsid), dwl's status on stdin (a pipe), with
# only the programs a test gives it (a PATH of stand-ins and the few system tools it needs).
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
AS=$HOME/.config/dwl/autostart.sh
DAEMONS="waybar kawa-panel mako foot udiskie wl-paste gammastep swayidle kawa-drives kawa-clipkeep"
SETSID=$(command -v setsid) PKILL=$(command -v pkill) SIDS=()
# tell — dwl prints its status (stdin) into the pipe; should its reader be gone, an error, not
# the end of the test (SIGPIPE stays ignored in this subshell only: autostart keeps the default)
tell() { (trap '' PIPE; cat >&6) 2>/dev/null; }

cleanup() { local s; for s in "${SIDS[@]}"; do ((s > 1)) && "$PKILL" -KILL -s "$s" -f "$TMP"; done; kill_bg; [[ -n $TMP ]] && rm -rf "$TMP"; }
# daemon NAME… — stand-ins that run until they are stopped (logged with their arguments)
# (they sleep as $TMP/sys/zzz: every process of a test session names the test's folder)
daemon() { local d; for d; do stub "$d" "trap 'kill \$! 2>/dev/null; exit 0' TERM HUP; \"$TMP/sys/zzz\" 600 & wait \$!"; done; }
setup() {   # setup [SHELL] — a home with the autostart, every program it starts a stand-in
  session_sandbox
  # every session this file starts ends with it, whatever happens (stand-ins sleep for minutes)
  # (only processes that name this test's folder: a session's number can be some other
  # session's once all of its processes are gone)
  trap cleanup EXIT
  ASH=${1:-sh=bash}
  config .config/dwl/autostart.sh
  # the system's own places (the polkit agent's) under $TMP/root
  sed -i "s|/usr/libexec/lxqt|$TMP/root/usr/libexec/lxqt|g" "$HOME/.config/dwl/autostart.sh"
  AS=$HOME/.config/dwl/autostart.sh
  mkdir -p "$TMP/root/usr/libexec" "$TMP/sys" "$TMP/shbin"
  # copies, never links: a write to a linked name would go through to /usr/bin or the repo
  cp "$BASH" "$TMP/shbin/sh"                    # bash as sh: Fedora's /bin/sh
  local t; for t in bash cat date env head id mkdir mv pkill rm sed wc; do cp "$(command -v "$t")" "$TMP/sys/$t"; done
  cp "$(command -v sleep)" "$TMP/sys/zzz"; cp "$BASH" "$TMP/sys/sh"
  mkdir -p "$TMP/kbin"; cp "$REPO/bin/kawa-dwlstatus" "$TMP/kbin/"   # the one helper of ours it runs
  daemon $DAEMONS
  stub systemctl; stub dbus-update-activation-environment; stub kawa-display; stub kawa-theme; stub kawa-steam; stub sleep
  daemon lxqt-policykit-agent; mv "$STUBS/lxqt-policykit-agent" "$TMP/root/usr/libexec/"   # (its one place)
  export WAYLAND_DISPLAY=wayland-1 DISPLAY=:1
}
# up — autostart as dwl starts it: setsid, its stdin the status pipe ($TMP/st, fd 6 is dwl's end)
up() {
  local sh=$TMP/shbin/sh i; [[ $ASH == dash ]] && sh=$(command -v dash)
  rm -f "$TMP/st"; mkfifo "$TMP/st"
  PATH="$STUBS:$TMP/kbin:$TMP/sys" "$SETSID" "$sh" "$AS" <"$TMP/st" >>"$HOME/.cache/dwl.log" 2>&1 &
  ASPID=$!; BG_PIDS+=("$ASPID"); exec 6>"$TMP/st"
  for ((i = 0; i < 500; i++)); do sidof SID "$ASPID"; [[ $SID == "$ASPID" ]] && break; nap 0.01; done
  SIDS+=("$SID")
}
# sidof VAR PID — the session PID belongs to ("" once it is gone); comm may hold spaces
sidof() { local l="" ; local -a f=(); { read -r l <"/proc/$2/stat"; } 2>/dev/null; l=${l##*) }; read -r -a f <<<"$l"; printf -v "$1" '%s' "${f[3]:-}"; }
# members — MEM: the name of every process in the session (a script run by bash or python
# by its own name, as pgrep -f would see it: kawa-dwlstatus)
PGREP=$(command -v pgrep)
members() {
  local p c; local -a a; MEM=()
  [[ $SID =~ ^[0-9]+$ ]] && ((SID > 1)) || return 0
  for p in $("$PGREP" -s "$SID"); do
    { read -r c <"/proc/$p/comm"; } 2>/dev/null || continue
    # a script (a stand-in, kawa-dwlstatus) by its file's whole name: comm keeps 15 letters
    mapfile -d '' -t a <"/proc/$p/cmdline" 2>/dev/null
    [[ ${a[0]:-} == */sh || ${a[0]:-} == bash ]] && [[ ${a[1]:-} == /* ]] && c=${a[1]##*/}
    MEM+=("$c")
  done
}
running() { local m n=0; members; for m in "${MEM[@]}"; do [[ $m == "$1" ]] && ((n++)); done; echo "$n"; }
settled() {   # settled NAME… — wait until each of these runs in the session
  local i d m ok
  for ((i = 0; i < 600; i++)); do
    members; ok=1
    for d; do for m in "${MEM[@]}" ""; do [[ $m == "$d" ]] && break; done; [[ $m == "$d" ]] || { ok=0; break; }; done
    ((ok)) && return 0; nap 0.05
  done
  return 1
}
left() { members; echo "${#MEM[@]}"; }
# waitfor FILE — until FILE has something in it (the reader is slow when the machine is busy)
waitfor() { local i; for ((i = 0; i < 400; i++)); do [[ -s $1 ]] && return 0; nap 0.05; done; return 1; }
# ncalls PREFIX N — until N calls of PREFIX are logged (bash only)
ncalls() { local i l c; local -a L; for ((i = 0; i < 400; i++)); do mapfile -t L <"$CALLS"; c=0; for l in "${L[@]}"; do [[ $l == "$1"* ]] && ((c++)); done; ((c >= $2)) && return 0; nap 0.05; done; return 1; }
# until_has FILE TEXT — until FILE holds TEXT (read by bash itself: no grep every few ms)
until_has() { local i x; for ((i = 0; i < 400; i++)); do x=""; { IFS= read -r -d '' x <"$1"; } 2>/dev/null; [[ $x == *"$2"* ]] && return 0; nap 0.05; done; return 1; }
gone() { local i; for ((i = 0; i < 300; i++)); do members; ((${#MEM[@]} == 0)) && return 0; nap 0.05; done; return 1; }
# quit — dwl quits: SIGTERM to the autostart's process group, then it waits for it
quit() { kill -TERM -- "-$SID" 2>/dev/null; wait "$ASPID"; ASRC=$?; exec 6>&-; }
# crash — dwl crashes: its end of the status pipe closes, no signal comes
crash() { exec 6>&-; wait "$ASPID"; ASRC=$?; }
down() { [[ $SID =~ ^[0-9]+$ ]] && ((SID > 1)) && "$PKILL" -KILL -s "$SID" -f "$TMP" 2>/dev/null; exec 6>&- 2>/dev/null; true; }

SP=" "   # (a stand-in called with no arguments logs "NAME ")
for SHL in sh=bash dash; do
  [[ $SHL == dash ]] && ! command -v dash >/dev/null && continue
  n=" [$SHL]"
case_ "login: the session handed to systemd first, then the display, the theme, the helpers$n"
setup "$SHL"; mkdir -p "$XDG_RUNTIME_DIR/dwl-bar/OLD"; up
settled waybar kawa-panel mako foot udiskie wl-paste gammastep swayidle kawa-dwlstatus lxqt-policykit-agent kawa-clipkeep && _ok || _no "not all started: $(cat "$CALLS" | tr '\n' '|')"
eq "$(grep -vE '^(waybar|kawa-panel|mako|foot|udiskie|kawa-drives|kawa-clipkeep|kawa-steam|wl-paste|gammastep|swayidle|lxqt-policykit-agent|pgrep|sleep|notify-send)( |$)' "$CALLS")" \
"systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE GTK_USE_PORTAL GDK_DEBUG
systemctl --user stop dwl-session.target
systemctl --user start dwl-session.target
systemctl --user start fedokawaii-remind.timer
systemctl --user start grub-boot-success.timer
kawa-display${SP}
kawa-theme apply" "in this order, the display's modes and the theme before any helper"
called "^waybar $"; called "^kawa-panel $"; called "^mako $"; called "^foot --server$"; called "^udiskie $"; called "^wl-paste --watch kawa-clip --store$"
called "^gammastep -l 25.35:55.40 -t 6500:4200$"; called "^lxqt-policykit-agent $"; called "^kawa-drives watch$"
called "^swayidle -w timeout 3600 wlopm --off '\*' resume wlopm --on '\*' before-sleep kawa-lock --now$"
called "^kawa-clipkeep $"; called "^kawa-steam --warm$"; not_called "^notify-send"
for d in waybar kawa-panel mako foot udiskie wl-paste gammastep swayidle kawa-dwlstatus kawa-clipkeep; do eq "$(running "$d")" 1 "one $d"; done
[[ ! -e $XDG_RUNTIME_DIR/dwl-bar/OLD ]] && _ok || _no "the last session's bar state was kept"
case_ "dwl's status reaches the bar (one monitor)$n"
block DP-1 1 3 2 0 '[]=' 0 "hello" | tell
waitfor "$BAR/kb.json"; eq "$(bar title)" '{"text":"hello"}'
case_ "logged out (dwl signals the session): everything it started is gone, its own exit clean$n"
quit; gone && _ok || _no "$(left) processes outlived the session"; eq "$ASRC" 0
down

case_ "dwl crashed (the status just ends, no signal): everything goes all the same$n"
setup "$SHL"; up; settled waybar udiskie swayidle kawa-dwlstatus
crash; gone && _ok || _no "processes outlived the crash: ${MEM[*]}"
eq "$ASRC" 0; down

case_ "logged out, in again: one of each helper, none left from before$n"
setup "$SHL"; up; settled waybar mako foot udiskie swayidle kawa-dwlstatus; quit; gone; first=$SID
up; settled waybar mako foot udiskie swayidle kawa-dwlstatus
for d in waybar mako foot udiskie swayidle kawa-dwlstatus; do eq "$(running "$d")" 1 "one $d"; done
SID=$first; eq "$(left)" 0 "nothing from the first login"
crash; down
done

ASH=sh=bash
case_ "two monitors: each bar's files from dwl's status"
setup; up; settled kawa-dwlstatus
{ block DP-1 0 1 1 0 '[]=' 0 "left"; block HDMI-A-1 1 2 2 0 '[M]' 0 "right"; } | tell
waitfor "$BAR/HDMI-A-1/title.json"; waitfor "$BAR/kb.json"; nap 1
eq "$(bar DP-1/title)" '{"text":"left"}'; eq "$(bar HDMI-A-1/title)" '{"text":"right"}'; eq "$(bar title)" '{"text":"right"}'
quit; down

case_ "run by hand while the session runs (its input is no pipe): refused, nothing started or removed"
setup; mkdir -p "$BAR/DP-1"
out=$(PATH="$STUBS:$TMP/kbin:$TMP/sys" "$SETSID" "$TMP/shbin/sh" "$AS" </dev/null 2>&1); r=$?
eq "$r" 2; has "$out" "log out and in"
eq "$(cat "$CALLS")" "" "nothing started"; [[ -d $BAR/DP-1 ]] && _ok || _no "the running session's bar files were removed"

case_ "a helper that crashes comes back; a clean exit is left alone"
setup; printf '0\n' >"$TMP/n"
stub udiskie 'n=$(cat "'"$TMP"'/n"); echo $((n + 1)) >"'"$TMP"'/n"; [ "$n" -lt 2 ] && exit 1; trap "exit 0" TERM; "'"$TMP"'/sys/zzz" 600 & wait $!'
stub mako 'exit 0'
up; settled waybar; ncalls udiskie 3; settled udiskie; nap 0.5
eq "$(grep -c '^udiskie' "$CALLS")" 3 "two crashes, then it stays"
eq "$(grep -c '^sleep 1$' "$CALLS")" 2 "a second's pause before each restart"
eq "$(grep -c '^mako' "$CALLS")" 1 "mako ended cleanly: not restarted (D-Bus starts it again)"
not_called "keeps stopping"; quit; down
case_ "a helper that keeps crashing: given up after five in a minute, with a notice that says so"
setup; stub waybar 'exit 1'; up; settled foot swayidle
until_has "$CALLS" 'keeps stopping'
eq "$(grep -c '^waybar' "$CALLS")" 5
called "^notify-send -a desktop -u critical waybar keeps stopping it was restarted 4 times in a minute; see ~/.cache/dwl.log$"
eq "$(running foot)" 1 "the rest runs on"; quit; down
case_ "swayidle (what locks before a sleep) crashing: never given up — paused with sleep blocked, said once"
setup; stub swayidle 'exit 1'; stub systemd-inhibit; up; settled foot
ncalls swayidle 11 && _ok || _no "swayidle was not started again after a pause: $(grep -c '^swayidle' "$CALLS") starts"
called "^systemd-inhibit --what=sleep --mode=block --who=swayidle --why=swayidle keeps stopping: nothing would lock before a sleep sleep 30$"
eq "$(grep -c '^notify-send.*swayidle keeps stopping' "$CALLS")" 1 "one notice"
not_called "it was restarted 4 times in a minute"; quit; down
case_ "the session's settings not handed to systemd: a notice, no other way tried"
setup; stub systemctl 'case "$*" in *import-environment*) exit 1 ;; esac'; up; settled foot swayidle
called "^notify-send -a desktop -u critical the session's settings did not reach systemd"
not_called "dbus-update-activation-environment"; quit; down
case_ "crashes far apart (more than a minute between): restarted every time, no notice"
setup; printf '0\n' >"$TMP/n"
stub waybar 'n=$(cat "'"$TMP"'/n"); echo $((n + 1)) >"'"$TMP"'/n"; [ "$n" -lt 6 ] && exit 1; trap "exit 0" TERM; "'"$TMP"'/sys/zzz" 600 & wait $!'
stub date 'echo . >>"'"$TMP"'/ticks"; n=$(wc -l <"'"$TMP"'/ticks"); echo $((1000000 + n * 61))'   # (61 s on with every look, whoever looks)
up; settled waybar foot
ncalls waybar 7; nap 0.5
eq "$(grep -c '^waybar' "$CALLS")" 7; not_called "keeps stopping"; quit; down

case_ "a program not installed: said once in a notice, the rest all start"
setup; rm "$STUBS/udiskie" "$STUBS/gammastep" "$STUBS/mako"; up; settled waybar foot wl-paste swayidle kawa-dwlstatus
until_has "$CALLS" udiskie
called "^notify-send -a desktop -u critical udiskie is not installed"
eq "$(grep -c 'udiskie' "$CALLS")" 1 "not tried again and again"
for d in waybar foot wl-paste swayidle kawa-dwlstatus; do eq "$(running "$d")" 1 "$d runs"; done
quit; down
case_ "the status reader itself missing: dwl's status is still read to its end, the session lasts"
setup; rm "$TMP/kbin/kawa-dwlstatus"; up; settled waybar
until_has "$CALLS" kawa-dwlstatus
called "^notify-send -a desktop -u critical kawa-dwlstatus is not installed"
head -c 300000 /dev/zero | tr '\0' '\n' | timeout 60 cat >&6 2>/dev/null && _ok || _no "the status pipe was not read (dwl would lose its status)"
kill -0 "$ASPID" 2>/dev/null && _ok || _no "the session ended with its reader"
crash; eq "$ASRC" 0; down
case_ "the polkit agent missing from /usr/libexec: said, like any helper the session keeps"
setup; rm "$TMP/root/usr/libexec/lxqt-policykit-agent"; up; settled waybar foot
until_has "$CALLS" 'lxqt-policykit-agent is not installed'
called "^notify-send -a desktop -u critical .*/usr/libexec/lxqt-policykit-agent is not installed"; not_called "^lxqt-policykit-agent"; quit; down

case_ "a slow display set-up (kawa-display): the helpers wait for it; dwl's status meanwhile is kept"
setup; stub kawa-display '"'"$TMP"'/sys/zzz" 2'; up
block DP-1 1 1 1 0 '[]=' 0 "while it was slow" | tell
nap 0.5; not_called "^waybar"; settled waybar kawa-dwlstatus
waitfor "$BAR/kb.json"; eq "$(bar title)" '{"text":"while it was slow"}'; quit; down
case_ "a slow helper (udiskie taking its time) holds back nothing"
setup; stub udiskie '"'"$TMP"'/sys/zzz" 3; trap "exit 0" TERM; "'"$TMP"'/sys/zzz" 600 & wait $!'; up
settled waybar foot swayidle kawa-dwlstatus && _ok; quit; down

case_ "your own autostart.local.sh: run beside the session, its output in dwl.log, ended with it"
setup; printf 'echo "mine started"\n"%s/sys/zzz" 600 &\n' "$TMP" >"$HOME/.config/dwl/autostart.local.sh"; up; settled waybar
until_has "$HOME/.cache/dwl.log" 'mine started'
has "$(cat "$HOME/.cache/dwl.log")" "mine started"; quit; gone && _ok || _no "your program outlived the session"; down
case_ "the session's settings file missing (~/.config/fedokawaii/env): the session starts all the same"
setup; rm "$HOME/.config/fedokawaii/env"; up; settled waybar foot swayidle kawa-dwlstatus && _ok || _no "the helpers did not start"
quit; down

case_ "autostart.sh is clean POSIX sh (bash -n, dash -n, shellcheck)"
rc 0 bash -n "$REPO/configs/home/.config/dwl/autostart.sh"
command -v dash >/dev/null && rc 0 dash -n "$REPO/configs/home/.config/dwl/autostart.sh"
rc 0 shellcheck -S warning -s sh "$REPO/configs/home/.config/dwl/autostart.sh"

case_ "the two timers autostart starts end with the session (PartOf it): the reminder, and the boot-success mark — a desktop gone sooner leaves the boot unmarked"
for f in systemd/user/fedokawaii-remind.timer systemd/user/grub-boot-success.timer.d/session.conf; do
  grep -qx 'PartOf=dwl-session.target' "$REPO/configs/home/.config/$f" && _ok || _no "$f is not PartOf=dwl-session.target"
done

done_
