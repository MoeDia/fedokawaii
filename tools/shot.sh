#!/usr/bin/env bash
# tools/shot.sh — screenshots to measure (tools/px.py), never to judge timing (a recorder or
# screencopy perturbs frames: tools/framestat.py does timing). The live session's own
# environment comes from its waybar; a headless run's from its runtime dir.
#   bash tools/shot.sh NAME [--region "X,Y WxH"] [--runtime DIR] [--both] [--settle S]
#     NAME        → /dev/shm/r27/NAME.png (with --both: NAME-dark.png and NAME-light.png)
#     --runtime   a headless dwl's XDG_RUNTIME_DIR (tools/hl-dwl.sh) instead of the session
#     --both      the theme switched to dark, shot, to light, shot, then back to the one it was
#                 (kawa-theme; --settle seconds for its wash to end, default 2.5)
# Prints the PNG paths. Exit 0 · 1 no picture · 2 misuse or no session.
set -u
name="" region="" rt="" both=0 settle=2.5
while (($#)); do
  case $1 in
    --region) region=$2; shift 2 ;;
    --runtime) rt=$2; shift 2 ;;
    --both) both=1; shift ;;
    --settle) settle=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "shot: unknown option $1" >&2; exit 2 ;;
    *) name=$1; shift ;;
  esac
done
[[ $name =~ ^[A-Za-z0-9._-]+$ ]] || { echo "usage: bash tools/shot.sh NAME [--region \"X,Y WxH\"] [--runtime DIR] [--both]" >&2; exit 2; }
out=/dev/shm/r27
mkdir -p "$out"
if [[ -n $rt ]]; then
  export XDG_RUNTIME_DIR=$rt
  for s in "$rt"/wayland-[0-9]; do export WAYLAND_DISPLAY=${s##*/}; break; done
else
  wb=$(pgrep -u "$USER" -xo waybar) || { echo "shot: no session (waybar) to shoot" >&2; exit 2; }
  eval "$(tr '\0' '\n' <"/proc/$wb/environ" | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')"
fi
[[ -n ${WAYLAND_DISPLAY:-} ]] || { echo "shot: no Wayland display" >&2; exit 2; }
grab() { if [[ -n $region ]]; then grim -g "$region" "$1"; else grim "$1"; fi && echo "$1"; }
if ((!both)); then grab "$out/$name.png" || exit 1; exit 0; fi
was=$(kawa-theme get 2>/dev/null) || { echo "shot: kawa-theme get failed" >&2; exit 2; }
for t in dark light; do
  [[ $(kawa-theme get) == "$t" ]] || { kawa-theme "$t" >/dev/null 2>&1; sleep "$settle"; }
  grab "$out/$name-$t.png" || exit 1
done
[[ $(kawa-theme get) == "$was" ]] || { kawa-theme "$was" >/dev/null 2>&1; sleep "$settle"; }
