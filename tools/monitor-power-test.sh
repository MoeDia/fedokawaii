#!/usr/bin/env bash
# tools/monitor-power-test.sh — the monitor really switched off and on, over DDC/CI (VCP D6 04,
# then 01), with the desktop running: the connector as DRM reports it each second while it is off,
# then the workspace, the layout, the window in focus and the mode compared with before (the
# monitor's state kept by name: MonKept in dwl). Puts his screen out for SECONDS (default 12): a
# notice first. If the monitor does not answer D6 01 it says so: the monitor's own button then.
#   bash tools/monitor-power-test.sh [SECONDS]
# Exit 0 · 1 something differs · 2 no session · 3 the monitor did not come back by itself
set -uo pipefail
secs=${1:-12}
wb=$(pgrep -u "$USER" -xo waybar) || { echo "no session (waybar)" >&2; exit 2; }
eval "$(tr '\0' '\n' <"/proc/$wb/environ" | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')"
conn=$(wlr-randr | awk '/^[^ ]/ { o = $1 } /Enabled: yes/ { print o; exit }')
sysd=$(printf '%s\n' /sys/class/drm/card*-"$conn" | sed -n 1p)
bus=$(readlink "$sysd/ddc"); bus=${bus##*i2c-}
[[ $bus =~ ^[0-9]+$ ]] || { echo "no DDC bus for $conn" >&2; exit 2; }
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/dev/shm/r27}/monitor-power-ddc
ddc=(ddcutil --bus "$bus" --skip-ddc-checks --sleep-multiplier 2 --maxtries "10,10,15")
state() {   # the bar's own files for this monitor: workspaces, layout, title; and the mode
  local d=$XDG_RUNTIME_DIR/dwl-bar/$conn f
  for f in "$d"/*.json; do printf '%s %s\n' "${f##*/}" "$(cat "$f")"; done
  wlr-randr | awk -v c="$conn" '/^[^ ]/ { o = $1 } o == c && /current/ { print "mode", $1, $3 }'
}
before=$(state)
line() { printf '%s  status=%s dpms=%s enabled=%s\n' "$(date +%T)" "$(cat "$sysd/status")" "$(cat "$sysd/dpms")" "$(cat "$sysd/enabled")"; }
line
"${ddc[@]}" setvcp D6 x04 --noverify; echo "sent D6 04 ($?)"
for ((i = 0; i < secs; i++)); do sleep 1; line; done
"${ddc[@]}" setvcp D6 x01 --noverify; r=$?; echo "sent D6 01 ($r)"
back=0
for ((i = 0; i < 25; i++)); do
  sleep 1; line
  if [[ $(cat "$sysd/status") == connected && $(cat "$sysd/dpms") == On ]] && [[ $("${ddc[@]}" getvcp D6 --terse 2>/dev/null) == *x01* ]]; then back=1; break; fi
done
((back)) || { echo "the monitor did not come back by itself: its own button"; exit 3; }
sleep 3
after=$(state)
if [[ $before == "$after" ]]; then
  echo "state identical:"; printf '%s\n' "$after" | cut -c1-120; exit 0
fi
echo "state DIFFERS:"; diff <(printf '%s\n' "$before") <(printf '%s\n' "$after"); exit 1
