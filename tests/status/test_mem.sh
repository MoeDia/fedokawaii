#!/usr/bin/env bash
# tests/status/test_mem.sh — kawa-mem, the bar's memory figure (a long-running script feeding
# waybar JSON). /proc/meminfo is a file the test rewrites (KAWA_PROC_MEMINFO); the wait between
# looks is cut short (KAWA_MEM_EVERY), and a line comes only when the figure changes.
. "$(dirname "$0")/lib.sh"
setup() { box; . "$HOME/.config/fedokawaii/icons.sh"; : >"$TMP/out"; }
info() { printf 'MemTotal:       %s kB\nMemFree:        1000 kB\nMemAvailable:   %s kB\n' "$1" "$2" >"$TMP/mi.tmp"; mv -f "$TMP/mi.tmp" "$TMP/mi"; }
start() { KAWA_PROC_MEMINFO=$TMP/mi KAWA_MEM_EVERY=0.05 kawa-mem >"$TMP/out" 2>"$TMP/err" & MEM=$!; }
stop() { kill "$MEM" 2>/dev/null; wait "$MEM" 2>/dev/null; }
lines() { wc -l <"$TMP/out"; }
last() { tail -n 1 "$TMP/out"; }
field() { python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$(last)" "$1"; }

case_ "at once: the chip and what programs hold (MemTotal − MemAvailable), in GiB to a tenth"
setup; info 33554432 27262976; start      # 32 GiB, 26 GiB available → 6.0G
waitfor 5 eval '(( $(lines) >= 1 ))' || _no "no first line"
eq "$(field text)" "${ICON_BAR_MEMORY}6.0G"; eq "$(field class)" calm
eq "$(field tooltip)" "RAM 18% of 32 GB"
json_lines "$(cat "$TMP/out")"
case_ "a line only when the figure changes: the same memory twice, still one line"
sleep 0.3; eq "$(lines)" 1
case_ "more in use: a new line (13.1G); past 85 %: class high"
info 33554432 19818086; waitfor 5 eval '(( $(lines) >= 2 ))' || _no "no second line"
eq "$(field text)" "${ICON_BAR_MEMORY}13.1G"; eq "$(field class)" calm
info 33554432 4194304; waitfor 5 eval '(( $(lines) >= 3 ))' || _no "no third line"
eq "$(field class)" high
case_ "every line is JSON"
json_lines "$(cat "$TMP/out")"
stop
case_ "misuse: exit 2"
rc 2 kawa-mem x

done_
