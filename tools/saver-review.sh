#!/usr/bin/env bash
# tools/saver-review.sh — the screensaver for the owner's design review, and what it costs: kawa-saver --idle in a
# kit (tools/kit.sh: headless dwl on the real GPU, the real lock under it), both moods.
#   bash tools/saver-review.sh OUTDIR [--measure S] [KIT OPTION…]
#     OUTDIR/saver-MOOD.png            asleep, as the screen shows it
#     OUTDIR/saver-MOOD-wake.png       a key: frames of the wake side by side, the last the lock
#     OUTDIR/saver-MOOD.webp           a recording (animated WebP: his page plays it): asleep, then the key, the lock
#     --measure S                      asleep for S seconds, then one line a mood: kawa-saver's and dwl's CPU (% of a
#                                      core), dwl's GPU time (% of the card, from its own fdinfo), kawa-saver's memory.
#                                      No recording while measuring (it would perturb both)
#   LOCK_HOME=DIR …   the lock's files before they are applied (as tools/regress/lock-start.sh)
# A recording's pace is only for looking. Exit 0 · 1 a number over its limit (said) · 2 the kit could not run.
set -u
here=$(cd "$(dirname "$0")" && pwd)
outdir=${1:?usage: saver-review.sh OUTDIR [--measure S] [KIT OPTION…]}; shift
measure=0
[[ ${1:-} == --measure ]] && { measure=$2; shift 2; }
W=$(mktemp -d /dev/shm/saver-review.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$W"' EXIT
mkdir -p "$outdir"
src=${LOCK_HOME:-$HOME}
cat >"$W/play.sh" <<'PLAY'
mkdir -p "$HOME/.local/share/fedokawaii" "$HOME/.local/lib" "$KIT_OUT/stub"
ln -s "$REAL/.local/share/fedokawaii/dark" "$REAL/.local/share/fedokawaii/light" "$HOME/.local/share/fedokawaii/"
ln -s "$REAL/.local/lib/fedokawaii" "$HOME/.local/lib/fedokawaii"
if [[ $REAL != "$CALLER" ]]; then
  cp "$REAL/.config/fedokawaii/lock.ui" "$HOME/.config/fedokawaii/lock.ui"
  for t in dark light; do cp "$REAL/.config/fedokawaii/themes/$t/"{gtklock.css,saver.conf} "$HOME/.config/fedokawaii/themes/$t/"; done
fi
printf '#!/bin/sh\nexit 0\n' >"$KIT_OUT/stub/logger"; chmod +x "$KIT_OUT/stub/logger"
# (what a process has burnt, in clock ticks; the GPU time of its render fds, in ns: amdgpu's fdinfo)
cpu() { local s; read -r s <"/proc/$1/stat"; s=${s##*) }; set -- $s; echo $((${12} + ${13})); }
gpu() { local f sum=0 v; for f in /proc/"$1"/fdinfo/*; do v=$(sed -n 's/^drm-engine-gfx:[[:space:]]*\([0-9]*\) ns/\1/p' "$f" 2>/dev/null); [[ -n $v ]] && { sum=$v; break; }; done; echo "$sum"; }
PATH="$KIT_OUT/stub:$PATH" KAWA_LOCK_SLEEP=0 kawa-saver --idle >"$KIT_OUT/saver.log" 2>&1 & S=$!
if ((MEASURE > 0)); then
  D=1                                # (hl-dwl.sh's fence: dwl is the first process of its own PID namespace)
  nap 3
  c0=$(cpu "$S") d0=$(cpu "$D") g0=$(gpu "$D") t0=$(date +%s.%N)
  nap "$MEASURE"
  c1=$(cpu "$S") d1=$(cpu "$D") g1=$(gpu "$D") t1=$(date +%s.%N)
  rss=$(sed -n 's/^VmRSS:[[:space:]]*\([0-9]*\).*/\1/p' "/proc/$S/status")
  python3 -I -c 'import sys
a = [float(v) for v in sys.argv[1:]]
c0, c1, d0, d1, g0, g1, t0, t1, rss = a
T = t1 - t0
print(f"saver {(c1 - c0) / T:.2f} % dwl {(d1 - d0) / T:.2f} % gpu {(g1 - g0) / 1e7 / T:.2f} % rss {rss / 1024:.0f} MB over {T:.0f} s")' \
    "$c0" "$c1" "$d0" "$d1" "$g0" "$g1" "$t0" "$t1" "$rss" >"$KIT_OUT/measure.txt" 2>>"$KIT_OUT/play.log"
else
  nap 2
  wf-recorder -y -c ffv1 -f "$KIT_OUT/rec.mkv" >/dev/null 2>&1 & R=$!
  nap 9
  shot asleep
  nap 1
  key space; nap 1.4
  shot awake
  kill -INT "$R"; wait "$R" 2>/dev/null
fi
PLAY
sed -i "1i REAL=$src CALLER=$HOME MEASURE=$measure" "$W/play.sh"
rc=0
for mood in dark light; do
  o=$W/$mood
  bash "$here/kit.sh" --theme "$mood" --time $((measure + 60)) "$@" --out "$o" --play "$W/play.sh" play >"$W/$mood.log" 2>&1 \
    || { echo "saver-review: the kit failed ($mood): $(tail -n 2 "$W/$mood.log")" >&2; exit 2; }
  if ((measure > 0)); then
    echo "$mood: $(cat "$o/measure.txt")"
    read -r _ c _ _ d _ _ g _ _ _ _ <"$o/measure.txt"
    ((${c%.*} < 2 && ${d%.*} < 4 && ${g%.*} < 3)) || { echo "saver-review: $mood over its limit (saver < 2 %, dwl < 4 %, gpu < 3 %)" >&2; rc=1; }
    continue
  fi
  cp "$o/asleep.png" "$outdir/saver-$mood.png"
  # (the frames by their own times: only the wake's, from the key on, for the sheet; all for the recording)
  mkdir -p "$o/f"
  ffmpeg -nostdin -loglevel error -i "$o/rec.mkv" -fps_mode passthrough "$o/f/%05d.png" || { echo "saver-review: no frames ($mood)" >&2; exit 2; }
  python3 -I "$here/saver-review.py" "$o/f" "$outdir/saver-$mood-wake.png" "$outdir/saver-$mood.webp" || exit 2
done
exit $rc
