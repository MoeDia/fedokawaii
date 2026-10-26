#!/usr/bin/env bash
# tests/session/test_framelog.sh — dwl's frame log (DWL_FRAMELOG, or SIGUSR2 in a running
# session: $XDG_RUNTIME_DIR/dwl-frames.log) and tools/framestat.py, which reads it: the frame
# times as measured inside dwl (a recorder perturbs them). A log with known answers
# (fixtures/frames.log: 144 Hz, ten frames with one refresh missed, a key 2 ms old when dwl got
# it, its frame on the glass 9 ms after, a window shown) — and the patch writes what it reads.
. "$(dirname "$0")/../lib/harness.sh"

P=$REPO/src/dwl/dwl.patch
out=$(python3 "$REPO/tools/framestat.py" "$(dirname "$0")/fixtures/frames.log" --json)
q() { python3 -c "import json,sys; d=json.load(sys.stdin)['HDMI-A-1']; print($1)" <<<"$out"; }

case_ "framestat: the refresh, the frames, one dropped in the streak, the builds"
[[ $(q "d['refresh_hz']") == 144.009 ]] && _ok || _no "refresh $(q "d['refresh_hz']")"
[[ $(q "d['commits'], d['presents'], d['held']") == "10 10 1" ]] && _ok || _no "counts $(q "d['commits'], d['presents'], d['held']")"
[[ $(q "d['streaks']['dropped'], d['streaks']['frames']") == "1 10" ]] && _ok || _no "drops $(q "d['streaks']")"
[[ $(q "d['build_us']['max']") == 190 ]] && _ok || _no "build max $(q "d['build_us']['max']")"
case_ "framestat: a key to the glass (from the event 11 ms, from dwl 9), a window from the press"
[[ $(q "d['input_to_glass_ms']['from_event']['p50'], d['input_to_glass_ms']['from_dwl']['p50']") == "11.0 9.0" ]] \
  && _ok || _no "latency $(q "d['input_to_glass_ms']")"
[[ $(q "d['windows'][0]['app']") == foot ]] && _ok || _no "window $(q "d['windows']")"

case_ "dwl writes those lines: F, H, P, K, B, M, W — on DWL_FRAMELOG or SIGUSR2, nothing otherwise"
for l in 'FLOG("F %lld %s %lld %d\n"' 'FLOG("H %lld %s\n"' 'FLOG("P %s %lld %u %d %u\n"' 'FLOG("K %lld %u %u %d\n"' \
         'FLOG("B %lld %u %u %d\n"' 'FLOG("M %lld %u\n"' 'FLOG("W %lld %s\n"'; do
  grep -qF "$l" "$P" && _ok || _no "missing: $l"
done
grep -q '^+#define FLOG(...) do { if (framelog) flogf(__VA_ARGS__); } while (0)$' "$P" \
  && grep -q '^+	} else if (signo == SIGUSR2 && write(cursorpipe\[1\], "F", 1) < 0) {$' "$P" \
  && grep -q 'snprintf(path, sizeof(path), "%s/dwl-frames.log", dir);' "$P" && _ok || _no "guard, SIGUSR2"
done_
