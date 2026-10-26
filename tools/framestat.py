#!/usr/bin/env python3
"""tools/framestat.py — what dwl's frame log says (DWL_FRAMELOG=FILE, see dwl.patch: F/H/P/K/B/M
lines): the frames as they reached the glass, measured inside dwl, never by a recorder.

  python3 tools/framestat.py LOG [--json] [--from T --to T] [--hz N]
  (T: µs on CLOCK_MONOTONIC; --hz: the refresh when the log has none — a headless output's
  presents carry no refresh, and come as soon as a frame is committed: not the glass)

Per output:
  frames       commits (F), held frames (H), commits that failed, presents (P)
  build        µs dwl took to build and commit a frame: p50 p95 p99 max
  streaks      runs of presents less than 3 refreshes apart (something moving): frames in
               them, and the dropped ones — an interval of k refreshes (k ≥ 2) is k-1 drops
  intervals    within streaks, in refreshes: p50 p95 p99 max
  latency      a key or button pressed → the first frame committed after it reaching the
               glass: from the event's own time (kernel) and from dwl getting it, ms p50 p95 max
               (meaningful when nothing else moves: the first frame after the input is its own)
  windows      each new window (W): the key or button pressed last before it (within 5 s) →
               its first frame on the glass, ms — an app's start as he sees it
Exit 0 · 1 the log has no frames · 2 misuse.
"""
import json
import sys


def pct(xs, p):
    if not xs:
        return None
    xs = sorted(xs)
    k = (len(xs) - 1) * p / 100.0
    lo = int(k)
    hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def main(argv):
    args = [a for a in argv[1:]]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args else 2
    path, as_json, t_from, t_to, hz = args[0], "--json" in args, None, None, None
    if "--hz" in args:
        hz = float(args[args.index("--hz") + 1])
    if "--from" in args:
        t_from = int(args[args.index("--from") + 1])
    if "--to" in args:
        t_to = int(args[args.index("--to") + 1])

    def inside(t):
        return (t_from is None or t >= t_from) and (t_to is None or t <= t_to)

    outs = {}
    inputs = []          # (t_dwl µs, t_event µs, kind)
    shown = []           # (t µs, app id)

    def out(name):
        return outs.setdefault(name, {"F": [], "H": 0, "fail": 0, "P": [], "refresh": None})

    with open(path, errors="replace") as f:
        for line in f:
            w = line.split()
            if not w:
                continue
            try:
                if w[0] == "F" and len(w) >= 5 and inside(int(w[1])):
                    o = out(w[2])
                    o["F"].append((int(w[1]), int(w[3])))
                    if w[4] != "1":
                        o["fail"] += 1
                elif w[0] == "H" and len(w) >= 3 and inside(int(w[1])):
                    out(w[2])["H"] += 1
                elif w[0] == "P" and len(w) >= 6 and inside(int(w[2])):
                    o = out(w[1])
                    flags = int(w[5])
                    if flags & 0x80:          # (not presented: discarded)
                        continue
                    o["P"].append(int(w[2]))
                    if int(w[4]) > 0:
                        o["refresh"] = int(w[4]) / 1000.0     # ns → µs
                elif w[0] == "W" and len(w) >= 3 and inside(int(w[1])):
                    shown.append((int(w[1]), w[2]))
                elif w[0] in ("K", "B") and len(w) >= 5 and w[4] == "1" and inside(int(w[1])):
                    inputs.append((int(w[1]), int(w[2]) * 1000, w[0]))
            except ValueError:
                continue

    report = {}
    for name, o in outs.items():
        r = {"commits": len(o["F"]), "held": o["H"], "failed": o["fail"], "presents": len(o["P"])}
        builds = [d for _, d in o["F"]]
        r["build_us"] = {k: (round(pct(builds, p)) if builds else None)
                         for k, p in (("p50", 50), ("p95", 95), ("p99", 99), ("max", 100))}
        ref = o["refresh"] or (1e6 / hz if hz else None)
        r["refresh_hz"] = round(1e6 / ref, 3) if ref else None
        pres = sorted(o["P"])
        ivals, frames, drops, streaks = [], 0, 0, 0
        if ref:
            run = False
            for a, b in zip(pres, pres[1:]):
                k = (b - a) / ref
                if k < 3.0:
                    if not run:
                        streaks += 1
                        run = True
                        frames += 1
                    frames += 1
                    ivals.append(k)
                    if k >= 1.5:
                        drops += int(round(k)) - 1
                else:
                    run = False
        r["streaks"] = {"count": streaks, "frames": frames, "dropped": drops}
        r["interval_refreshes"] = {k: (round(pct(ivals, p), 3) if ivals else None)
                                   for k, p in (("p50", 50), ("p95", 95), ("p99", 99), ("max", 100))}
        # input → glass: the first commit after the input, then the first present after it
        lat_ev, lat_dwl = [], []
        fs = sorted(t for t, _ in o["F"])
        fi = pi = 0
        for t_dwl, t_ev, _ in sorted(inputs):
            while fi < len(fs) and fs[fi] < t_dwl:
                fi += 1
            if fi == len(fs):
                break
            while pi < len(pres) and pres[pi] < fs[fi]:
                pi += 1
            if pi == len(pres):
                break
            if pres[pi] - t_dwl > 500000:       # (nothing drawn within half a second: not its frame)
                continue
            if t_ev:                             # (a virtual keyboard's events carry no time)
                lat_ev.append((pres[pi] - t_ev) / 1000.0)
            lat_dwl.append((pres[pi] - t_dwl) / 1000.0)
        r["input_to_glass_ms"] = {
            "n": len(lat_ev),
            "from_event": {k: (round(pct(lat_ev, p), 2) if lat_ev else None) for k, p in (("p50", 50), ("p95", 95), ("max", 100))},
            "from_dwl": {k: (round(pct(lat_dwl, p), 2) if lat_dwl else None) for k, p in (("p50", 50), ("p95", 95), ("max", 100))},
        }
        wins = []
        presses = sorted(t for t, _, _ in inputs)
        for t_w, app in sorted(shown):
            before = [t for t in presses if t <= t_w and t_w - t <= 5000000]
            after = [p for p in pres if p >= t_w]
            if before and after:
                wins.append({"app": app, "ms": round((after[0] - before[-1]) / 1000.0, 1)})
        r["windows"] = wins
        report[name] = r

    if not any(r["commits"] or r["presents"] for r in report.values()):
        print("framestat: no frames in " + path, file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps(report, indent=1))
        return 0
    for name, r in report.items():
        b, iv, s, la = r["build_us"], r["interval_refreshes"], r["streaks"], r["input_to_glass_ms"]
        print(f"{name}  {r['refresh_hz']} Hz")
        print(f"  frames     {r['commits']} committed · {r['held']} held · {r['failed']} failed · {r['presents']} on the glass")
        print(f"  build µs   p50 {b['p50']} · p95 {b['p95']} · p99 {b['p99']} · max {b['max']}")
        print(f"  streaks    {s['count']} · {s['frames']} frames · {s['dropped']} dropped")
        print(f"  intervals  (refreshes) p50 {iv['p50']} · p95 {iv['p95']} · p99 {iv['p99']} · max {iv['max']}")
        fe, fd = la["from_event"], la["from_dwl"]
        print(f"  input→glass ms ({la['n']})  from the event p50 {fe['p50']} · p95 {fe['p95']} · max {fe['max']}"
              f"  · from dwl p50 {fd['p50']} · p95 {fd['p95']} · max {fd['max']}")
        for wn in r["windows"]:
            print(f"  window     {wn['app']}: {wn['ms']} ms from the press to its first frame")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
