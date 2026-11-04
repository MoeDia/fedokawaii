#!/usr/bin/env bash
# tools/regress/bar-cycles.sh — never again (r27-asobi, 4 Nov 18:49: back from the play world, no bar): a monitor
# that goes away and comes back, as at every VT switch, makes waybar end one bar and start another, and its
# teardown can hang for good (waybar's cancel and join of its modules' threads: the main thread on a futex under
# Custom::~Custom, the thread being joined in __malloc_arena_thread_freeres). A headless kit (tools/kit.sh: real
# waybar, real modules) with its output off and on N times, kawa-display --hotplug after each as dwl runs it: the
# bar must be on the screen at the end, its main thread in poll, however often the teardown hung.
#   bash tools/regress/bar-cycles.sh [--bin DIR] [--dwl BIN] [--cycles N] [--out DIR]
# Exit 0 held · 1 no bar at the end (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")/../.." && pwd)
bin=$here/bin dwl=/usr/local/bin/dwl cycles=40 out=/dev/shm/r27/bar-cycles
while (($#)); do case $1 in --bin) bin=$2; shift 2 ;; --dwl) dwl=$2; shift 2 ;; --cycles) cycles=$2; shift 2 ;; --out) out=$2; shift 2 ;; *) echo "usage: bar-cycles.sh [--bin DIR] [--dwl BIN] [--cycles N] [--out DIR]" >&2; exit 2 ;; esac; done
rm -rf "$out"; mkdir -p "$out"
play=$out/cycles.play
cat >"$play" <<PLAY
nap 2.5
shot before
# (the session's keep, autostart.sh: what ends the bar here restarts it)
( while :; do sleep 0.5; [[ -n \$(pgrep -o -x waybar) ]] || waybar >/dev/null 2>&1 </dev/null & done ) >/dev/null 2>&1 &
keep=\$!
kept=\$(pgrep -o -x waybar) restarted=0
for i in \$(seq 1 $cycles); do
  wlr-randr --output HEADLESS-1 --off; nap 0.\$(( RANDOM % 9 + 1 ))
  wlr-randr --output HEADLESS-1 --on --custom-mode 1920x1080@144Hz; nap 0.\$(( RANDOM % 9 + 1 ))
  kawa-display --hotplug </dev/null >/dev/null 2>&1
  sleep 0.7
  b=\$(pgrep -o -x waybar); [[ \$b == "\$kept" ]] || { restarted=\$((restarted + 1)); kept=\$b; }
done
nap 4
kawa-display --hotplug </dev/null >/dev/null 2>&1
nap 4
shot after
kill "\$keep" 2>/dev/null
b=\$(pgrep -o -x waybar); say "cycles $cycles, the bar started anew \$restarted times; main thread: \$(cat /proc/\$b/wchan)"
PLAY
PATH="$HOME/.local/bin:$PATH" nice -n 10 bash "$here/tools/kit.sh" --theme dark --bin "$bin" --dwl "$dwl" --play "$play" --time $((cycles * 5 + 80)) --out "$out" play >"$out/kit.log" 2>&1 || { [[ -e $out/after.png ]] || { echo "bar-cycles: the kit did not run ($out/kit.log)"; exit 2; }; }
cat "$out/play.log"
n=$(magick compare -metric AE -fuzz 8% "$out/before.png[150x27+0+0]" "$out/after.png[150x27+0+0]" null: 2>&1 | sed 's/ .*//'); n=${n%%.*}
grep -q 'main thread: poll' "$out/play.log" || { echo "bar-cycles: the bar's main thread is not in poll at the end"; exit 1; }
[[ ${n:-99999} -lt 200 ]] || { echo "bar-cycles: no bar at the end ($n pixels of its left end differ; $out)"; exit 1; }
echo "bar-cycles: held, $cycles cycles"
