#!/usr/bin/env bash
# tests/session/test_push.sh — a value the bar shows follows its change at once: whoever
# changes it (the panel's meter dragged, a key) pushes it to the bar's long-running module
# (kawa-bar's bar_push: a line into kawa-bar.NAME.PID, its fifo), which draws it without
# asking anyone — no process started per step, the newest of a burst drawn, none behind.
# Timed: 60 pushes, each drawn within a few ms (p50, p95, p99 printed).
. "$(dirname "$0")/../lib/harness.sh"

sandbox
config .config/fedokawaii
R=$XDG_RUNTIME_DIR; mkdir -p "$R"
: >"$R/kawa-brightness.asked"                      # (no monitor asked in the background)
echo 50 >"$R/kawa-brightness.level"
out=$TMP/bri; mkfifo "$out"
kawa-brightness --bar >"$out" & mod=$!; H_CLEANUP+=("kill $mod 2>/dev/null")
exec 7<"$out"
IFS= read -r -t 5 -u 7 l
case_ "the brightness module: the level known, then every pushed one"
has "$l" '50<span'
for _ in {1..50}; do [[ -p $R/kawa-bar.brightness.$mod ]] && break; sleep 0.02; done
[[ -L $R/kawa-bar.brightness.$mod ]] && _ok || _no "no push link for the module"
. "$REPO/bin/kawa-bar"
bar_push brightness 40; IFS= read -r -t 2 -u 7 l; has "$l" '40<span'
case_ "a burst (a drag faster than drawing): the newest drawn, never an older one after it"
for v in 41 42 43 44 45 46 47 48 49 77; do bar_push brightness "$v"; done
last=""; while IFS= read -r -t 0.3 -u 7 l; do last=$l; done
has "$last" '77<span'
case_ "lit while its slider is open: a wake redraws it with the light, no tooltip"
/bin/sleep 300 >/dev/null 2>&1 & p=$!; H_CLEANUP+=("kill $p 2>/dev/null"); echo "$p" >"$R/kawa-panel-brightness.open"
"$REPO/bin/kawa-dwlstatus" --wake; IFS= read -r -t 2 -u 7 l
has "$l" '"class":"active"'; has "$l" '"tooltip":""'
rm -f "$R/kawa-panel-brightness.open"; "$REPO/bin/kawa-dwlstatus" --wake; IFS= read -r -t 2 -u 7 l; lacks "$l" active
case_ "push → drawn: 60 steps — half within 5 ms, every one within 100 ms (a loaded test machine; no process started)"
lat=()
for ((v = 1; v <= 60; v++)); do
  t0=${EPOCHREALTIME/[.,]/}; bar_push brightness "$v"; IFS= read -r -t 2 -u 7 l
  lat+=($(( ${EPOCHREALTIME/[.,]/} - t0 )))
done
mapfile -t s < <(printf '%s\n' "${lat[@]}" | sort -n)
p50=${s[30]} p95=${s[56]} p99=${s[59]}
echo "  push → line: p50 $((p50 / 1000)).$(( p50 % 1000 / 100 )) ms · p95 $((p95 / 1000)).$(( p95 % 1000 / 100 )) ms · p99 $((p99 / 1000)).$(( p99 % 1000 / 100 )) ms"
((p50 < 5000 && p99 < 100000)) && _ok || _no "p50 ${p50} µs, p99 ${p99} µs"
case_ "the module ends with the bar: its fifo and link go"
kill "$mod"; wait "$mod" 2>/dev/null; exec 7<&-
for _ in {1..50}; do [[ -e $R/kawa-bar.brightness.$mod ]] || break; sleep 0.02; done
[[ -e $R/kawa-bar.brightness.$mod || -e $R/kawa-bar.wake.$mod ]] && _no "left behind" || _ok

done_
