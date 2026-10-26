#!/usr/bin/env bash
# tools/perf.sh — the desktop's performance, measured the same way every time (round 27's
# "before" and "after"): in the running session, driven through its own keys (wtype), every
# frame timed inside dwl (its frame log, SIGUSR2 — tools/framestat.py), never by a recorder.
#   bash tools/perf.sh [OUTDIR]        (default ~/.cache/fedokawaii-perf/<date-time>)
#   bash tools/perf.sh --again OUTDIR  the phases read again from OUTDIR's frames.log (after a
#                                      change to framestat.py): OUTDIR/phases.txt keeps their times
# Opens and closes windows and menus on workspaces 8 and 9 (workspace 1 shown at the end); run it
# while nobody is at the keyboard (its keys go to whatever has the focus).
# Phases, each its own slice of the frame log:
#   idle      30 s untouched: CPU %, GPU busy % and watts, VRAM, RAM; the desktop's processes (PSS)
#   boot      systemd-analyze: firmware, loader, kernel, initrd, userspace; the slowest units
#   terminal  10 × Super+Return then Super+Q: press → window on the glass; the open/close frames
#   switch    20 workspace switches with windows on both: frames dropped in the cross-fades
#   typing    80 characters into a terminal, 40 ms apart: key → glass (dwl's part: wtype's
#             virtual keyboard has no kernel time)
#   menus     Super+U, Super+N, Super+V (warm), Super+Space, Super+/ , Super+C, Super+E: press → glass
#   nvim      nvim --startuptime, 5 runs: total ms
# Writes OUTDIR/report.txt (and the raw logs). Exit 0 · 2 no session to drive.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# phases OUT — each phase's slice of OUT/frames.log, through framestat (phases.txt: name from to)
phases() {
  while read -r ph a b; do
    printf '\n── %s\n' "$ph"
    python3 "$here/framestat.py" "$1/frames.log" --from "$a" --to "$b" | sed 's/^/  /'
  done <"$1/phases.txt"
}
if [[ ${1:-} == --again ]]; then
  [[ -f ${2:-}/phases.txt ]] || { echo "perf: no phases.txt in ${2:-?}" >&2; exit 2; }
  phases "$2"; exit 0
fi
out=${1:-$HOME/.cache/fedokawaii-perf/$(date +%Y%m%d-%H%M%S)}
mkdir -p "$out"
wb=$(pgrep -u "$USER" -xo waybar) || { echo "perf: no session (waybar) to drive" >&2; exit 2; }
eval "$(tr '\0' '\n' <"/proc/$wb/environ" | grep -E '^(WAYLAND_DISPLAY|DISPLAY|XDG_RUNTIME_DIR|DBUS_SESSION_BUS_ADDRESS)=' | sed 's/^/export /')"
dwl=$(pgrep -u "$USER" -xo dwl) || { echo "perf: no dwl" >&2; exit 2; }
log=$XDG_RUNTIME_DIR/dwl-frames.log
card=$(tr '\0' '\n' <"/proc/$dwl/environ" | sed -n 's|^WLR_DRM_DEVICES=/dev/dri/||p')
dev=/sys/class/drm/${card:-card0}/device
rep=$out/report.txt
: >"$rep"
say() { printf '%s\n' "$*" | tee -a "$rep"; }
mono() { python3 -c 'import time; print(time.clock_gettime_ns(time.CLOCK_MONOTONIC) // 1000)'; }
key() { wtype -s 120 "$@" 2>/dev/null; }          # (the virtual keyboard registered first)
super() { key -M logo -k "$1" -m logo; }
declare -A from to
phase() { from[$1]=$(mono); }
done_() { to[$1]=$(mono); }

say "fedokawaii perf — $(date '+%F %T') — $(uname -r) — dwl $(stat -c %y /usr/local/bin/dwl | cut -d. -f1)"

# ── idle (before the log: nothing drawn, nothing logged)
say ""; say "── idle (30 s untouched)"
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ </proc/stat
gb=0 gn=0 pw=0
for _ in $(seq 60); do
  gb=$((gb + $(cat "$dev/gpu_busy_percent" 2>/dev/null || echo 0)))
  p=$(cat "$dev"/hwmon/hwmon*/power1_average 2>/dev/null | head -1); pw=$((pw + ${p:-0}))
  gn=$((gn + 1)); sleep 0.5
done
read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ </proc/stat
busy=$(( (u2+n2+s2+q2+sq2+st2) - (u1+n1+s1+q1+sq1+st1) )); all=$(( busy + (i2+w2) - (i1+w1) ))
say "  CPU busy $(awk -v b=$busy -v a=$all 'BEGIN{printf "%.2f", 100*b/a}') % · load $(cut -d' ' -f1-3 /proc/loadavg)"
say "  GPU busy $((gb / gn)) % · $(awk -v p=$pw -v n=$gn 'BEGIN{printf "%.1f", p/n/1e6}') W · VRAM $(( $(cat "$dev/mem_info_vram_used") / 1048576 )) MiB"
say "  RAM $(free -m | awk '/^Mem:/{print $3" MiB used, "$6" MiB cache, "$7" MiB available of "$2}')"
say "  the desktop's processes (PSS MiB):"
for p in $(pgrep -u "$USER"); do
  c=$(cat "/proc/$p/comm" 2>/dev/null) || continue
  k=$(awk '/^Pss:/{print $2}' "/proc/$p/smaps_rollup" 2>/dev/null) || continue
  echo "$c ${k:-0}"
done | awk '{s[$1]+=$2; n[$1]++} END {for (c in s) printf "%s %d %d\n", c, s[c]/1024, n[c]}' | sort -k2 -nr | head -18 \
  | while read -r c m n; do say "    $(printf '%-22s %5s MiB  (%s)' "$c" "$m" "$n")"; done
say "  total PSS of $USER: $(for p in $(pgrep -u "$USER"); do awk '/^Pss:/{print $2}' "/proc/$p/smaps_rollup" 2>/dev/null; done | awk '{s+=$1} END {printf "%d", s/1024}') MiB"

# ── boot
say ""; say "── boot"
say "  $(systemd-analyze 2>/dev/null | head -1)"
systemd-analyze blame 2>/dev/null | head -6 | sed 's/^ */    /' | tee -a "$rep" >/dev/null
systemd-analyze critical-chain graphical.target 2>/dev/null | sed -n '4,9p' | sed 's/^/    /' >>"$rep"

# ── the frame log on (afresh)
logging() {                                            # (dwl holds it open: on)
  local f
  for f in /proc/"$dwl"/fd/*; do [[ $(readlink "$f") == "$log" ]] && return 0; done
  return 1
}
logging && kill -USR2 "$dwl" && sleep 0.3               # (one left on: off first)
rm -f "$log"; kill -USR2 "$dwl"; sleep 0.5
logging || { echo "perf: dwl keeps no frame log (an old dwl, without SIGUSR2?)" >&2; exit 2; }
super 9; sleep 1

phase terminal
for _ in $(seq 10); do key -M logo -k Return -m logo; sleep 1.2; super q; sleep 1; done
done_ terminal

phase switch
key -M logo -k Return -m logo; sleep 1; key -M logo -k Return -m logo; sleep 1
super 8; sleep 0.6; key -M logo -k Return -m logo; sleep 1
for _ in $(seq 10); do super 9; sleep 0.7; super 8; sleep 0.7; done
done_ switch

phase typing
super 8; sleep 0.6
key -d 40 "the quick brown fox jumps over the lazy dog and back again ok"; sleep 0.5
key -M ctrl -k u -m ctrl; sleep 0.3
done_ typing
super q; sleep 0.8; super 9; sleep 0.6; super q; sleep 0.8; super q; sleep 0.8

phase menus
for k in u n v; do for _ in 1 2 3; do super "$k"; sleep 1.2; super "$k"; sleep 1; done; done
for k in space slash c; do for _ in 1 2 3; do super "$k"; sleep 1.5; key -k Escape; sleep 1; done; done
for _ in 1 2 3; do super e; sleep 1.5; super q; sleep 1; done          # (yazi: closed as a window)
done_ menus
kill -USR2 "$dwl"; sleep 0.3
logging && { echo "perf: the frame log did not stop" >&2; }
cp "$log" "$out/frames.log"
super 1

for ph in terminal switch typing menus; do echo "$ph ${from[$ph]} ${to[$ph]}"; done >"$out/phases.txt"
phases "$out" >>"$rep"

# ── nvim
say ""; say "── nvim --startuptime (5 runs, ms)"
for i in 1 2 3 4 5; do
  nvim --headless --startuptime "$out/nvim$i.log" +qa >/dev/null 2>&1
  grep 'NVIM STARTED' "$out/nvim$i.log" | tail -1 | awk '{printf "%s ", $1 + 0}' >>"$out/nvim.txt"
done
say "  $(cat "$out/nvim.txt")"
cat "$rep"
echo "perf: $rep"
