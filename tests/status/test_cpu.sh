#!/usr/bin/env bash
# tests/status/test_cpu.sh — kawa-cpu, the bar's CPU meter (a long-running script feeding
# waybar JSON). /proc/stat is a named pipe (KAWA_PROC_STAT) that the test holds open both ways
# and writes one reading into at a time; the wait between readings is cut to nothing
# (KAWA_CPU_EVERY=0). So each reading makes exactly one line — no clock involved.
. "$(dirname "$0")/lib.sh"
setup() { box; . "$HOME/.config/fedokawaii/icons.sh"; U=0 N=0 S=0 I=0 W=0 Q=0 SQ=0 ST=0 G=0; }
# pipe NAME — a stand-in /proc/stat at $TMP/NAME, held open (read-write: kawa-cpu's every open
# finds a writer, a line written waits there for its next read)
pipe() { mkfifo "$TMP/$1"; exec {SFD}<>"$TMP/$1"; }
start() {   # start — kawa-cpu reading the pipe, its lines into $TMP/out
  pipe stat; : >"$TMP/out"
  KAWA_PROC_STAT=$TMP/stat KAWA_CPU_EVERY=0 kawa-cpu >"$TMP/out" 2>"$TMP/err" & CPU=$!
}
# write — the counters now as /proc/stat's first line (as Linux 6.x prints it: user nice
# system idle iowait irq softirq steal guest guest_nice), then wait for the line it makes
write() {
  # shellcheck disable=SC2034  # (read by the eval in waitfor)
  local want=$(($(wc -l <"$TMP/out") + 1))
  printf 'cpu  %s %s %s %s %s %s %s %s %s 0\n' "$U" "$N" "$S" "$I" "$W" "$Q" "$SQ" "$ST" "$G" >&"$SFD"
  waitfor 5 eval '(( $(wc -l <"$TMP/out") >= want ))' || _no "no line for a reading"
}
# load BUSY IDLE [CPUS] — one reading: BUSY and IDLE jiffies (per CPU) since the last one
load() { local c=${3:-1}; U=$((U + $1 * c)); I=$((I + $2 * c)); write; }
stop() { kill "$CPU" 2>/dev/null; wait "$CPU" 2>/dev/null; exec {SFD}>&-; }
lastline() { tail -n 1 "$TMP/out"; }
pct() { text_of "$(lastline)" | awk '{ print $NF }'; }
graph() { text_of "$(lastline)" | awk '{ print $2 }'; }
segs() { local s="" p; for p; do s+=$(eval "printf %s \"\$ICON_EQ_$p\""); done; printf '%s' "$s"; }

# ── the first line, the readings ─────────────────────────────────────────────
case_ "at once, before any reading: the chip, an empty graph, 0 % — the bar keeps its width from the start"
setup; start; U=1000 I=9000; write
eq "$(lastline)" "{\"text\":\"$ICON_CPU $(segs 0 0 0 0 0 0 0 0)   0%\",\"class\":\"calm\",\"tooltip\":\"CPU — the last 16 seconds\"}"
json_lines "$(cat "$TMP/out")"
case_ "half busy: 50 %, the newest column on the right (3 of 5 segments)"
load 50 50
eq "$(pct)" 50%; eq "$(graph)" "$(segs 0 0 0 0 0 0 0 3)"
case_ "the columns: 1–20 % one segment … 81–100 % five"
load 1 99; load 20 80
eq "$(graph)" "$(segs 0 0 0 0 0 3 1 1)" "50 1 20 → 3 1 1"
for p in 21 40 41 60 61 80 81 100; do load "$p" $((100 - p)); done
eq "$(graph)" "$(segs 2 2 3 3 4 4 5 5)" "21 40 41 60 61 80 81 100 → 2 2 3 3 4 4 5 5"
case_ "above 80 %: class busy; 80 % exactly: calm"
eq "$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["class"])' "$(lastline)")" busy
load 80 20
eq "$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["class"])' "$(lastline)")" calm
case_ "every line is JSON, and the text always the same width (0 %, 5 %, 100 %)"
load 5 95; load 0 100; load 100 0
json_lines "$(cat "$TMP/out")"
eq "$(while IFS= read -r l; do t=$(text_of "$l"); echo "${#t}"; done <"$TMP/out" | sort -u)" 15 "chip, space, 8 columns, space, 4"
stop

case_ "the history: 8 readings, the oldest leaves on the left"
setup; start; write
for p in 10 30 50 70 90 100 0 20; do load "$p" $((100 - p)); done
eq "$(graph)" "$(segs 1 2 3 4 5 5 0 1)"
load 100 0
eq "$(graph)" "$(segs 2 3 4 5 5 0 1 5)" "the 10 % reading is gone"
stop

# ── what counts as busy ──────────────────────────────────────────────────────
case_ "user, nice, system, irq, softirq and steal count; idle and iowait do not"
setup; start; write
N=$((N + 10)) S=$((S + 10)) Q=$((Q + 5)) SQ=$((SQ + 5)) ST=$((ST + 10)) I=$((I + 40)) W=$((W + 20)); write
eq "$(pct)" 40%
case_ "guest time is inside user already: not counted twice"
G=$((G + 100)) I=$((I + 100)); write
eq "$(pct)" 0%
case_ "iowait stepping back between readings (it does): never below 0, never above 100"
W=$((W - 50)) U=$((U + 10)); write
p=$(pct); p=${p%\%}; ((p >= 0 && p <= 100)) && _ok || _no "$p %"
case_ "counters that did not move (a VM paused): 0 %, no division by zero"
write; eq "$(pct)" 0%
kill -0 "$CPU" 2>/dev/null && _ok || _no "kawa-cpu died"
stop

case_ "64 CPUs (counters 64 times as big): one core busy is 1 %, all of them 100 %"
setup; start; U=$((64 * 8640000)) I=$((64 * 86400000)); write
U=$((U + 100)) I=$((I + 6300)); write; eq "$(pct)" 1% "1 busy core of 64"
load 100 0 64; eq "$(pct)" 100%
case_ "… after 300 days up (counters past 2^31): still right"
U=$((U + 64 * 2592000000)) I=$((I + 64 * 2592000000)); write
load 25 75 64; eq "$(pct)" 25%
stop
case_ "1 CPU: the same"
setup; start; U=500 I=500; write
load 100 0; eq "$(pct)" 100%
load 1 3; eq "$(pct)" 25%
stop

# ── the bar going and coming ─────────────────────────────────────────────────
case_ "the bar goes away (SIGPIPE ignored, as under waybar): the next line fails and the script ends"
setup; pipe stat
( trap '' PIPE; exec env KAWA_PROC_STAT="$TMP/stat" KAWA_CPU_EVERY=0 kawa-cpu ) 2>/dev/null | head -n 1 >"$TMP/first" &
printf 'cpu  1 0 0 1 0 0 0 0 0 0\n' >&"$SFD"
waitfor 3 test -s "$TMP/first"
for i in 1 2 3; do printf 'cpu  %s 0 0 2 0 0 0 0 0 0\n' "$i" >&"$SFD"; done
waitfor 3 eval '[[ -z $(jobs -pr) ]]' && _ok || { _no "kawa-cpu kept running for nobody"; pkill -f "KAWA_PROC_STAT=$TMP" 2>/dev/null; }
wait 2>/dev/null; exec {SFD}>&-
case_ "started again (waybar restarts it): a fresh, empty history at once"
setup; start; U=99999 I=99999; write
eq "$(graph)" "$(segs 0 0 0 0 0 0 0 0)"; eq "$(pct)" 0%
stop
case_ "two bars (two monitors) run one each: both keep going"
setup; pipe s1; f1=$SFD; pipe s2; f2=$SFD
KAWA_PROC_STAT=$TMP/s1 KAWA_CPU_EVERY=0 kawa-cpu >"$TMP/o1" & a=$!
KAWA_PROC_STAT=$TMP/s2 KAWA_CPU_EVERY=0 kawa-cpu >"$TMP/o2" & b=$!
for f in "$f1" "$f2"; do printf 'cpu  1 0 0 1 0 0 0 0 0 0\ncpu  51 0 0 51 0 0 0 0 0 0\n' >&"$f"; done
waitfor 3 eval '[[ $(wc -l <"$TMP/o1") == 2 && $(wc -l <"$TMP/o2") == 2 ]]' && _ok || _no "a line missing"
eq "$(text_of "$(tail -n 1 "$TMP/o2")" | awk '{ print $NF }')" 50%
kill "$a" "$b" 2>/dev/null; wait "$a" "$b" 2>/dev/null; exec {f1}>&- {f2}>&-

case_ "the real /proc/stat (no stand-in), the 2 s wait: a first line at once, valid JSON"
setup
timeout 1 kawa-cpu >"$TMP/out" 2>"$TMP/err"
eq "$(wc -l <"$TMP/out")" 1; json_lines "$(cat "$TMP/out")"; eq "$(cat "$TMP/err")" ""

# ── misuse ───────────────────────────────────────────────────────────────────
case_ "misuse (2) and --help (0), nothing drawn"
setup
out=$(kawa-cpu --help); r=$?
eq "$r" 0; has "$out" "kawa-cpu"; lacks "$out" '{"text"'
rc 2 kawa-cpu --interval 1
case_ "a wait that is not a number falls back to 2 s"
setup; timeout 1 env KAWA_CPU_EVERY='1; rm -rf x' kawa-cpu >"$TMP/out" 2>"$TMP/err"
eq "$(wc -l <"$TMP/out")" 1; eq "$(cat "$TMP/err")" ""

done_
