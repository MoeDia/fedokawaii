#!/usr/bin/env bash
# tools/perf-load.sh — the standard heavy-use scene, every frame timed inside dwl (its frame
# log; tools/framestat.py): a 1080p60 video playing (mpv, hardware decoding as configured),
# Brave with 10 animated pages on a throw-away profile (never his own), 8 terminals running
# btop, and a workspace switch every 2 s for 2 minutes through the real keys; CPU, GPU, RAM and
# dwl's own memory sampled meanwhile. It uses workspaces 6 and 7 and closes all it opened
# (Super+Q on its own windows), then shows workspace 1. Run it while nobody is at the keyboard.
#   bash tools/perf-load.sh [OUTDIR]   (default ~/.cache/fedokawaii-perf/<date-time>-load)
# Writes OUTDIR/load.txt (framestat's report + the samples) and OUTDIR/frames.log.
# Exit 0 · 2 no session to drive.
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=${1:-$HOME/.cache/fedokawaii-perf/$(date +%Y%m%d-%H%M%S)-load}
mkdir -p "$out"
wb=$(pgrep -u "$USER" -xo waybar) || { echo "perf-load: no session (waybar) to drive" >&2; exit 2; }
eval "$(tr '\0' '\n' <"/proc/$wb/environ" | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')"
dwl=$(pgrep -u "$USER" -xo dwl) || { echo "perf-load: no dwl" >&2; exit 2; }
card=$(tr '\0' '\n' <"/proc/$dwl/environ" | sed -n 's|^WLR_DRM_DEVICES=/dev/dri/||p')
dev=/sys/class/drm/${card:-card0}/device
log=$XDG_RUNTIME_DIR/dwl-frames.log
shm=/dev/shm/r27/load
mkdir -p "$shm/pages"
key() { wtype -s 120 "$@" 2>/dev/null; }
super() { key -M logo -k "$1" -m logo; }
logging() { local f; for f in /proc/"$dwl"/fd/*; do [[ $(readlink "$f") == "$log" ]] && return 0; done; return 1; }

# the scene's material: a 130 s 1080p60 video (made once), ten pages that never stop moving
[[ -s $shm/video.mp4 ]] || ffmpeg -loglevel error -f lavfi -i testsrc2=size=1920x1080:rate=60 -t 130 \
  -c:v libx264 -preset ultrafast -pix_fmt yuv420p -y "$shm/video.mp4" || exit 2
for i in $(seq 10); do
  cat >"$shm/pages/p$i.html" <<EOF
<!doctype html><title>load $i</title><style>
body{margin:0;background:#101018;overflow:hidden}
.b{position:absolute;width:120px;height:120px;border-radius:12px;animation:m ${i}s linear infinite alternate}
@keyframes m{from{transform:translate(0,0) rotate(0)}to{transform:translate(70vw,60vh) rotate(720deg)}}
</style>$(for k in $(seq 24); do printf '<div class="b" style="left:%dpx;top:%dpx;background:hsl(%d,70%%,55%%);animation-delay:-%d.%ds"></div>' $((k * 37 % 900)) $((k * 53 % 500)) $((k * 15)) $((k % 7)) $((k % 10)); done)
EOF
done

super 6; sleep 0.6
mpv --loop=inf --really-quiet "$shm/video.mp4" >/dev/null 2>&1 &
sleep 1.5
urls=(); for i in $(seq 10); do urls+=("file://$shm/pages/p$i.html"); done
brave-origin --user-data-dir="$shm/brave" --no-first-run --no-default-browser-check --new-window "${urls[@]}" >/dev/null 2>&1 &
sleep 4
super 7; sleep 0.6
for _ in $(seq 8); do footclient -e btop >/dev/null 2>&1 & sleep 0.4; done
sleep 3

logging && kill -USR2 "$dwl" && sleep 0.3
rm -f "$log"; kill -USR2 "$dwl"; sleep 0.3
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ </proc/stat
samples=$out/samples.txt
: >"$samples"
t0=$SECONDS
for _ in $(seq 30); do
  super 6; sleep 1
  echo "$((SECONDS - t0)) gpu $(cat "$dev/gpu_busy_percent" 2>/dev/null) vram $(( $(cat "$dev/mem_info_vram_used") / 1048576 )) used $(free -m | awk '/^Mem:/{print $3}') dwl_rss $(awk '/^VmRSS/{print $2}' "/proc/$dwl/status")" >>"$samples"
  ((SECONDS - t0 > 60 && SECONDS - t0 < 65)) && grim "$out/mid-run.png" 2>/dev/null   # (the scene, seen once)
  sleep 1; super 7; sleep 2
done
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ </proc/stat
kill -USR2 "$dwl"; sleep 0.3
cp "$log" "$out/frames.log"

# close what it opened: the terminals (workspace 7), then Brave and mpv (6), then workspace 1
for _ in $(seq 8); do super q; sleep 0.4; done
super 6; sleep 0.6
super q; sleep 1; super q; sleep 1
sleep 1
[[ -d $shm/brave ]] && rm -rf "$shm/brave"     # (its throw-away profile)
super 1

busy=$(( (u2+n2+s2+q2+sq2+st2) - (u1+n1+s1+q1+sq1+st1) )); all=$(( busy + (i2+w2) - (i1+w1) ))
{
  echo "fedokawaii perf-load — $(date '+%F %T') — 1080p60 video + Brave 10 animated pages + 8 btop, a switch every 2 s, 120 s"
  echo "  CPU busy over the run: $(awk -v b=$busy -v a=$all 'BEGIN{printf "%.1f", 100*b/a}') %"
  awk '{g+=$3; v=$5; u+=$7; r=$9; n++} END {printf "  GPU busy avg %.0f %% · VRAM %d MiB · RAM used avg %.0f MiB · dwl RSS at the end %d KiB\n", g/n, v, u/n, r}' "$samples"
  python3 "$here/framestat.py" "$out/frames.log" --anim | grep -vE '^  \S+ +(c[0-9]+|g) ' | sed 's/^/  /'
} | tee "$out/load.txt"
