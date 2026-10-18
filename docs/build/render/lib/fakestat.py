#!/usr/bin/env python3
"""A steadily advancing stand-in for the first line of /proc/stat (bind-mounted over it
inside shoot.sh's namespace), so the bar's CPU history (kawa-cpu: one reading every 2 s,
busy = user+nice+system+irq+softirq+steal over all) is the same on every run instead of
depending on whatever else this shared machine is doing.

  fakestat.py FILE    rewrite FILE in place every 0.25 s (fixed width: readers never see
                      a half-written line)

The load follows PATTERN, one value per 2-second window (per cent of the whole machine);
the other lines of the real /proc/stat are copied once."""
import sys
import time

PATTERN = [14, 27, 45, 33, 58, 72, 41, 22]
WINDOW = 2.0
HZ = 100 * 2                       # USER_HZ × 2 CPUs: ticks per second for the machine

path = sys.argv[1]
with open("/proc/stat") as f:
    rest = "".join(f.readlines()[1:])
user, system, idle = 300000.0, 60000.0, 900000.0
t0 = last = time.monotonic()
with open(path, "w") as out:
    while True:
        now = time.monotonic()
        dt, last = now - last, now
        pct = PATTERN[int((now - t0) / WINDOW) % len(PATTERN)] / 100.0
        ticks = HZ * dt
        user += ticks * pct * 0.75
        system += ticks * pct * 0.25
        idle += ticks * (1 - pct)
        line = "cpu  %14d %14d %14d %14d %14d %14d %14d %14d %14d %14d\n" % (
            user, 0, system, idle, 0, 0, 0, 0, 0, 0)
        out.seek(0)
        out.write(line + rest)
        out.flush()
        time.sleep(0.25)
