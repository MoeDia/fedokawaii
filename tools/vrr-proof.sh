#!/usr/bin/env bash
# tools/vrr-proof.sh — FreeSync proven, by three witnesses that cannot agree by accident, on the
# real screen (about a minute: a full-screen test picture takes the focus and goes away):
#   1 the card: DRM's vrr_capable and VRR_ENABLED (kawa-display --vrr), asked during each step
#   2 dwl: the intervals between its presents (its frame log, SIGUSR2): with FreeSync they follow
#     the picture's rate (10 ms at 100 fps), without it they are whole refreshes (6.94 ms apart)
#   3 the monitor itself: its own measure of the refresh (DDC/CI VCP 0xAE), asked once a second
# The steps: 100 fps and 60 fps with FreeSync on, 40 fps (below the panel's 48 Hz floor: frames
# doubled), then 100 fps with it off; 72 is no test (2 × 6.94 ms either way). His setting
# (~/.config/fedokawaii/vrr) is put back at the end, whatever happens.
#   bash tools/vrr-proof.sh [OUTDIR]     (default /dev/shm/r27/vrr-proof-<time>; report.txt there)
# Exit 0 · 2 no session, or the frame log already in use · 3 a witness disagrees
set -uo pipefail
out=${1:-/dev/shm/r27/vrr-proof-$(date +%H%M%S)}
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"
wb=$(pgrep -u "$USER" -xo waybar) || { echo "vrr-proof: no session (waybar)" >&2; exit 2; }
eval "$(tr '\0' '\n' <"/proc/$wb/environ" | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')"
dwl=$(pgrep -u "$USER" -xo dwl) || { echo "vrr-proof: no dwl" >&2; exit 2; }
log=$XDG_RUNTIME_DIR/dwl-frames.log
for fd in /proc/"$dwl"/fd/*; do
  [[ $(readlink "$fd" 2>/dev/null) == "$log" ]] && { echo "vrr-proof: dwl's frame log is in use by another run" >&2; exit 2; }
done
conn=$(wlr-randr | awk '/^[^ ]/ { o = $1 } /Enabled: yes/ { print o; exit }')
sysd=$(printf '%s\n' /sys/class/drm/card*-"$conn" | head -n 1)
bus=$(readlink "$sysd/ddc"); bus=${bus##*i2c-}
[[ $bus =~ ^[0-9]+$ ]] || { echo "vrr-proof: no DDC bus for $conn" >&2; exit 2; }
export XDG_CACHE_HOME=$out/ddc-cache
ddc=(ddcutil --bus "$bus" --skip-ddc-checks --sleep-multiplier 2 --maxtries 10,10,15)
vrrf=$HOME/.config/fedokawaii/vrr
saved=$(cat "$vrrf" 2>/dev/null || echo games)
player=""
finish() {
  [[ -n $player ]] && kill "$player" 2>/dev/null
  printf '%s\n' "$saved" >"$vrrf"; kill -USR1 "$dwl" 2>/dev/null
}
trap finish EXIT
trap 'exit 130' INT TERM HUP

ae() { "${ddc[@]}" getvcp AE 2>/dev/null | sed -nE 's/.*: *([0-9.]+) *hz.*/\1/Ip'; }
{
  echo "connector $conn ($sysd), DDC bus $bus, kernel $(uname -r), his setting: $saved"
  echo "EDID: AMD VSDB and range limits as DRM reads them:"
  sudo -n cat "/sys/kernel/debug/dri/$(basename "$(readlink -f "$sysd/device/device")")/$conn/vrr_range" 2>/dev/null | tr '\n' ' '; echo
  echo
  printf '%-8s %-5s %-14s %-22s %s\n' "freesync" "fps" "card now" "presents ms (p5 p50 p95)" "monitor's own Hz (each second)"
} | tee "$out/report.txt"

step() {   # step SETTING FPS
  printf '%s\n' "$1" >"$vrrf"; kill -USR1 "$dwl"
  mpv --no-config --really-quiet --fs --no-audio --no-osc --no-input-default-bindings --title=vrr-proof \
      --vo=gpu-next "av://lavfi:testsrc2=size=480x270:rate=$2,format=yuv420p" >/dev/null 2>&1 &
  player=$!
  sleep 3
  local now hz=()
  now=$(kawa-display --vrr 2>/dev/null | awk -F'\t' -v c="$conn" '$1 == c { print $2 "/" $3 }')
  kill -USR2 "$dwl"; sleep 0.3
  local i; for ((i = 0; i < 8; i++)); do hz+=("$(ae)"); sleep 0.6; done
  kill -USR2 "$dwl"; sleep 0.2
  cp "$log" "$out/frames-$1-$2.log" 2>/dev/null
  kill "$player" 2>/dev/null; wait "$player" 2>/dev/null; player=""
  local pres
  pres=$(python3 -I - "$out/frames-$1-$2.log" "$conn" <<'PY'
import sys
t = []
for l in open(sys.argv[1]):
    w = l.split()
    if len(w) >= 6 and w[0] == "P" and w[1] == sys.argv[2]:
        t.append(int(w[2]))
d = sorted((b - a) / 1000 for a, b in zip(t, t[1:]))
if len(d) < 10:
    print("too few (%d)" % len(d))
else:
    print("%.2f %.2f %.2f" % (d[len(d) // 20], d[len(d) // 2], d[len(d) * 19 // 20]))
PY
  )
  printf '%-8s %-5s %-14s %-22s %s\n' "$1" "$2" "${now:-?}" "$pres" "${hz[*]}" | tee -a "$out/report.txt"
  sleep 1
}
step games 100
step games 60
step games 40
step off 100
echo "report: $out/report.txt"
exit 0
