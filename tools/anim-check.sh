#!/usr/bin/env bash
# tools/anim-check.sh — every animation dwl draws on its own, run headless on the real GPU and
# judged from dwl's own frame log (the A lines: a window's c<kind>, a ghost's g, the wash's w),
# never from a recording: each one a step every refresh (none skipped), its progress rising to
# 1, and as long as config.h says, ± 1 frame (its pace from the steps themselves, its last step
# within a frame of its end):
#   open anim_open_ms (c1) · close anim_close_ms (g) · tiled windows making room anim_slide_ms
#   (c5) · a workspace switch: the old leaving anim_tag_each_ms (c3), the new over anim_tag_ms
#   (c2) · the wash anim_wash_ms (w)
# (warm windows, the panels' menus, notices, the level display, the lock: their own checks in
# tools/regress/ — warm-exit, menu-first-click, level-display — they need the desktop's scripts)
#   bash tools/anim-check.sh [--dwl BIN] [--keep DIR]
# Exit 0 all held · 1 one broken (said) · 2 could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
dwl=$HOME/.local/src/dwl/dwl keep=
while (($#)); do
  case $1 in
    --dwl) dwl=$2; shift 2 ;;
    --keep) keep=$2; shift 2 ;;
    *) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0" >&2; exit 2 ;;
  esac
done
cfg=$(dirname "$dwl")/config.h
[[ -f $cfg ]] || cfg=$here/../src/dwl/config.h
out=$(mktemp -d /dev/shm/anim-check.XXXXXX)
trap 'rm -rf "$out"' EXIT
cat >"$out/inside.sh" <<'INSIDEEND'
R=$XDG_RUNTIME_DIR
key() { wtype -s "$1" -M logo -k "$2" -m logo 2>/dev/null; }
swaybg -c '#3a2a20' >/dev/null 2>&1 &
sleep 0.5
foot -e sleep 60 >/dev/null 2>&1 & f1=$!; sleep 1.0          # a window opens
foot -e sleep 60 >/dev/null 2>&1 & f2=$!; sleep 1.0          # another, on the stack
kill "$f1"; sleep 1.0                                          # the master closes: the other slides there
key 1000 2; sleep 1.0                                          # workspace 2: the window leaves
key 300 1; sleep 1.0                                           # back: it comes in
mkfifo "$R/ans"; exec 3<>"$R/ans"
echo "wash cover $R/ans" 1<>"$R/dwl-warm"; read -r -t 2 _ <&3
echo "wash go" 1<>"$R/dwl-warm"; sleep 1.8                    # the wash
kill "$f2"; sleep 0.8
INSIDEEND
bash "$here/hl-dwl.sh" "$out/inside.sh" --dwl "$dwl" --keep "$out/k" --time 40 >/dev/null 2>&1 \
  || { echo "anim-check: the headless run failed: $(tail -n 3 "$out/k/script.log" 2>/dev/null)" >&2; exit 2; }
[[ -n $keep ]] && { mkdir -p "$keep" && cp -r "$out/k/." "$keep/"; }
python3 -I - "$out/k/frames.log" "$cfg" <<'PYEND'
import re, statistics, sys
log, cfg = sys.argv[1], open(sys.argv[2]).read()
ms = {k: int(v) for k, v in re.findall(r"anim_(\w+)_ms\s*=\s*(\d+)", cfg)}
want = {"c1": ("open", ms["open"]), "g": ("close", ms["close"]), "c5": ("slide", ms["slide"]),
        "c3": ("workspace out", ms["tag_each"]), "c2": ("workspace in", ms["tag"]), "w": ("wash", ms["wash"])}
steps = {}
for line in open(log):
    w = line.split()
    if len(w) >= 5 and w[0] == "A":
        steps.setdefault((w[2], w[3], w[5] if len(w) > 5 else ""), []).append((int(w[1]), float(w[4])))
seqs = []   # a sequence ends when its progress falls back or 50 ms pass without a step
for (o, kind, _), st in steps.items():
    cur = []
    for t, p in sorted(st):
        if cur and (p < cur[-1][1] or t - cur[-1][0] > 50000):
            seqs.append((kind, cur)); cur = []
        cur.append((t, p))
    if cur:
        seqs.append((kind, cur))
gaps = [b[0] - a[0] for _, s in seqs for a, b in zip(s, s[1:])]
if not gaps:
    print("anim-check: no animation in the frame log"); sys.exit(1)
frame = statistics.median(gaps)          # µs: the output's refresh as dwl stepped it
bad, seen = [], set()
print(f"anim-check: a frame is {frame / 1000:.2f} ms here")
for kind, s in seqs:
    name, cfg_ms = want.get(kind, (kind, None))
    (t0, p0), last = s[0], s[-1]
    run = [x for x in s if x[1] < 0.999]
    ta, pa = run[-1] if run else s[0]
    pace = (ta - t0) / (pa - p0) / 1000 if pa > p0 else None
    mg = max((b[0] - a[0] for a, b in zip(s, s[1:])), default=0)
    skipped = sum(round((b[0] - a[0]) / frame) - 1 for a, b in zip(s, s[1:]) if (b[0] - a[0]) > 1.5 * frame)
    late = (last[0] - (t0 - p0 * cfg_ms * 1000)) / 1000 - cfg_ms if cfg_ms else None
    print(f"  {name:14} {len(s):4} steps · paced {pace if pace is None else round(pace, 1)} ms (config {cfg_ms})"
          f" · last step {late if late is None else round(late, 1)} ms after its end · max gap {mg / 1000:.1f} ms"
          f" · skipped {skipped}")
    if cfg_ms is None:
        continue
    seen.add(kind)
    f = frame / 1000
    if pace is None or abs(pace - cfg_ms) > f:
        bad.append(f"{name}: paced {'?' if pace is None else round(pace, 1)} ms, not {cfg_ms} ± a frame")
    if last[1] < 0.999: bad.append(f"{name}: never reached its end")
    elif not (-0.5 * f <= late <= 1.5 * f): bad.append(f"{name}: its last step {late:.1f} ms after its end")
    if skipped: bad.append(f"{name}: {skipped} steps skipped")
    if any(b[1] < a[1] for a, b in zip(s, s[1:])): bad.append(f"{name}: progress fell back")
for k, (name, _) in want.items():
    if k not in seen: bad.append(f"{name}: never ran")
for b in bad:
    print("anim-check: " + b)
print("anim-check: " + ("all held" if not bad else f"{len(bad)} broken"))
sys.exit(1 if bad else 0)
PYEND
