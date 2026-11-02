#!/usr/bin/env python3
"""tools/proc-load.py — what a process tree costs while it runs, from /proc alone (T53, T60):
  proc-load.py spawns SECONDS PID     every process born under PID (any depth) in the window, by argv
  proc-load.py wakeups SECONDS PID…   each process under the PIDs: context switches (≈ wake-ups) a
                                      minute and CPU ms in the window, the busiest first
e.g. the bar: proc-load.py wakeups 60 "$(pgrep -x waybar)". Reads only; exit 0 · 2 misuse."""
import collections
import os
import sys
import time


def parent(p):
    try:
        with open(f"/proc/{p}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except OSError:
        return None


def argv(p):
    try:
        with open(f"/proc/{p}/cmdline", "rb") as f:
            return f.read().replace(b"\0", b" ").decode(errors="replace").strip()[:100]
    except OSError:
        return ""


def under(roots):
    tree = collections.defaultdict(list)
    for d in os.listdir("/proc"):
        if d.isdigit():
            tree[parent(d)].append(int(d))
    out, todo = [], list(roots)
    while todo:
        p = todo.pop()
        out.append(p)
        todo += tree.get(p, [])
    return out


def spawns(dur, root):
    seen = {int(d) for d in os.listdir("/proc") if d.isdigit()}
    tree, born, end = {root}, collections.Counter(), time.monotonic() + dur
    while time.monotonic() < end:   # (a look every 20 ms: a process living less than that can slip by)
        for d in os.listdir("/proc"):
            if d.isdigit() and int(d) not in seen:
                seen.add(int(d))
                if parent(d) in tree:
                    tree.add(int(d))
                    born[argv(d) or "(gone at once)"] += 1
        time.sleep(0.02)
    for a, n in born.most_common():
        print(f"{n:5d}  {a}")
    print(f"total {sum(born.values())} in {dur:.0f} s")


def look(p):
    try:
        with open(f"/proc/{p}/status") as f:
            sw = sum(int(ln.split()[1]) for ln in f if "ctxt_switches:" in ln)
        with open(f"/proc/{p}/stat") as f:
            st = f.read().rsplit(")", 1)[1].split()
        return sw, (int(st[11]) + int(st[12])) * 1000 // os.sysconf("SC_CLK_TCK"), argv(p)
    except OSError:
        return None


def wakeups(dur, roots):
    ps = under(roots)
    a = {p: look(p) for p in ps}
    time.sleep(dur)
    b = {p: look(p) for p in ps}
    rows = sorted(((b[p][0] - a[p][0], b[p][1] - a[p][1], p, b[p][2]) for p in ps if a[p] and b[p]), reverse=True)
    for sw, cpu, p, name in rows:
        print(f"{sw * 60 / dur:8.0f}/min {cpu:6d} ms  {p:7d}  {name}")
    print(f"sum {sum(r[0] for r in rows) * 60 / dur:.0f} wake-ups/min, {sum(r[1] for r in rows)} ms CPU in {dur:.0f} s")


if __name__ == "__main__":
    try:
        mode, dur, pids = sys.argv[1], float(sys.argv[2]), [int(a) for a in sys.argv[3:]]
        assert mode in ("spawns", "wakeups") and dur > 0 and pids and (mode == "wakeups" or len(pids) == 1)
    except (IndexError, ValueError, AssertionError):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    if mode == "spawns":
        spawns(dur, pids[0])
    else:
        wakeups(dur, pids)
