#!/usr/bin/env bash
# tools/regress/browser-login.sh — never again a flood of browser windows at login (the owner, 4 Nov
# 21:05, 21:20: twice, also after a reboot; kawa-browser --warm missed its own --warm once the
# extension's flag stood first, and started itself without end). A separate test session: a headless
# dwl of its own (tools/hl-dwl.sh: a PID namespace, its own runtime dir and D-Bus), its own home, the
# real Helium and the repository's launcher, the extension in place as on a real machine, the
# profile of a browser that crashed with windows open. The login is autostart.sh's own line and its
# own keep(). Every window that ever opens is on the record (toplevels.py).
#   the login            no window, not for a moment; one hidden browser; no chain of starters
#   a press              one window
#   closed, then a press one window: the old ones do not come back
#   killed, a press      keep() starts it again, hidden; one window; no question about old windows
#   no display           a press from a shell with none opens nothing
# Nothing of the session or of the real home is read or written.
#   bash tools/regress/browser-login.sh [--keep DIR]
# Exit 0 held · 1 broken (each said) · 2 could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
keep=""; [[ ${1:-} == --keep ]] && keep=$2
[[ -x /usr/bin/helium ]] || { echo "browser-login: Helium is not installed" >&2; exit 2; }
out=$(mktemp -d /dev/shm/regress-browser.XXXXXX)
trap 'rm -rf "$out"' EXIT
home=$out/home
mkdir -p "$home/.local/bin" "$home/.local/share/fedokawaii/browser" "$home/.config/net.imput.helium/Default" "$home/.cache"
cp "$repo/bin/kawa-browser" "$home/.local/bin/"
cp "$repo"/configs/home/.local/share/fedokawaii/browser/* "$home/.local/share/fedokawaii/browser/"
printf '#!/bin/sh\ncat >/dev/null\n' >"$home/.local/bin/kawa-downloads"; chmod +x "$home/.local/bin/kawa-downloads"
# (the profile as theme.sh leaves it, its first-start page answered; and as a crash leaves it)
jq -n '.helium.completed_onboarding = true | .helium.services.user_consented = false | .helium.services.schema_version = 1
  | .session.restore_on_startup = 5 | .profile.exit_type = "Crashed"' >"$home/.config/net.imput.helium/Default/Preferences"
# autostart.sh's own keep() and its own browser line, nothing else of it: the rest of the file speaks
# to the real user manager
auto=$repo/configs/home/.config/dwl/autostart.sh
line=$(grep -E '^[{ ]*.*keep kawa-browser --warm' "$auto") || { echo "browser-login: no warm line in autostart.sh" >&2; exit 2; }
{ echo 'notify-send() { echo "notice: $*" >>"$OUT/notices"; }'
  sed -n '/^keep() {$/,/^}$/p' "$auto"
  printf '%s\n' "$line"       # (the login's wait, 8 s, as it stands)
  echo 'wait'
} >"$out/login.sh"
cat >"$out/inside.sh" <<'INSIDE'
export HOME=$OUT/home XDG_CONFIG_HOME=$OUT/home/.config XDG_CACHE_HOME=$OUT/home/.cache XDG_DATA_HOME=$OUT/home/.local/share
export PATH=$HOME/.local/bin:$PATH BROWSER=true
win=$OUT/windows
: >"$win"
python3 -I "$REGRESS/toplevels.py" "$win" &
sleep 0.5
opened() { grep -c '^open' "$win"; }
live() { echo $(( $(grep -c '^open' "$win") - $(grep -c '^close' "$win") )); }
mains() { ps -eo args | grep -c '^/opt/helium/helium .*--no-startup-window'; }
starters() { ps -eo args | grep -c 'kawa-browser'; }
wait_open() { n=0; while [ "$(opened)" -lt "$1" ] && [ $n -lt 200 ]; do sleep 0.1; n=$((n + 1)); done; sleep "${2:-3}"; }
say() { echo "$*" >>"$OUT/result"; }

sh "$OUT/login.sh" </dev/null >/dev/null 2>&1 &
# the login: 8 s of its own wait, then the browser's start; looked at for half a minute
top=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
  s=$(starters); [ "$s" -gt "$top" ] && top=$s; sleep 1
done
say "login windows-ever $(opened)"
say "login hidden-browsers $(mains)"
say "login starters-at-most $top"
kawa-browser; wait_open 1
say "press1 windows-ever $(opened) live $(live) hidden-browsers $(mains)"
grim "$OUT/press1.png"
kawa-browser; wait_open 2
say "press2 windows-ever $(opened) live $(live)"
# both closed as his Super+Q closes them (the compositor asks the window), the browser left running
n=0; while [ "$(live)" -gt 0 ] && [ $n -lt 8 ]; do wtype -s 1000 -M logo q -m logo; sleep 1.5; n=$((n + 1)); done
say "closed live $(live) hidden-browsers $(mains)"
before=$(opened)
kawa-browser; wait_open $((before + 1))
say "press3 new-windows $(( $(opened) - before )) live $(live)"
# killed outright, as a crash would
for p in $(ps -eo pid,args | grep '^ *[0-9]* /opt/helium/helium .*--no-startup-window' | awk '{print $1}'); do kill -KILL "$p"; done
n=0; while [ "$(mains)" -gt 0 ] && [ $n -lt 50 ]; do sleep 0.1; n=$((n + 1)); done
sleep 6
say "killed live $(live) hidden-browsers $(mains)"
before=$(opened)
kawa-browser; wait_open $((before + 1))
say "press4 new-windows $(( $(opened) - before )) live $(live) hidden-browsers $(mains)"
grim "$OUT/press4.png"
before=$(opened)
env -u WAYLAND_DISPLAY -u DISPLAY "$HOME/.local/bin/kawa-browser" about:blank; say "nodisplay status $?"
sleep 3
say "nodisplay new-windows $(( $(opened) - before ))"
say "pidrate $(a=$(cut -d' ' -f5 /proc/loadavg); sleep 2; b=$(cut -d' ' -f5 /proc/loadavg); echo $(( (b - a) / 2 )))"
INSIDE
export OUT=$out REGRESS=$here
bash "$here/../hl-dwl.sh" "$out/inside.sh" --time 200 --keep "$out/kept" >"$out/hl.log" 2>&1; rc=$?
[[ -n $keep ]] && { mkdir -p "$keep"; cp -a "$out"/result "$out"/windows "$out"/press*.png "$out"/kept "$out"/hl.log "$keep"/ 2>/dev/null; cp -a "$out"/notices "$keep"/ 2>/dev/null; }
[[ -s $out/result ]] || { echo "browser-login: the session did not run (status $rc): $(tail -n 2 "$out/hl.log")" >&2; exit 2; }
fail=0
want() {   # want LINE: that exact line in the result
  grep -qxF "$1" "$out/result" || { echo "browser-login: wanted [$1], got [$(grep -F "${1%% *} " "$out/result" | tr '\n' ';')]" >&2; fail=1; }
}
want "login windows-ever 0"
want "login hidden-browsers 1"
want "press1 windows-ever 1 live 1 hidden-browsers 1"
want "press2 windows-ever 2 live 2"
want "closed live 0 hidden-browsers 1"
want "press3 new-windows 1 live 1"
want "killed live 0 hidden-browsers 1"
want "press4 new-windows 1 live 1 hidden-browsers 1"
want "nodisplay status 1"
want "nodisplay new-windows 0"
top=$(sed -n 's/^login starters-at-most //p' "$out/result")
[[ $top =~ ^[0-9]+$ ]] && ((top <= 3)) || { echo "browser-login: starters at the login: $top (a chain?)" >&2; fail=1; }
((fail)) && { cat "$out/result" >&2; exit 1; }
echo "browser-login: held: no window at the login, one for each press, no old window back, a crash no different"
exit 0
