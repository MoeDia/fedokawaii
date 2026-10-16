#!/usr/bin/python3
"""tests/session/fake_waybar.py LOG [catch|ignore] — a stand-in for waybar, named "waybar" (as
pgrep and /proc/PID/comm see it), that writes one line to LOG per real-time signal it gets.

  catch    handles SIGRTMIN+8 … +13 like waybar's custom modules do (SigCgt shows them), and
           logs each delivery: "8", "9" … in the order the kernel hands them over
  ignore   has not installed its handlers yet (waybar still starting): a poke would kill it

SIGRTMAX asks for a "flush" line: it is queued after every poke already sent, so once
"flush" is in LOG every earlier poke is too (real-time signals queue, none is lost).
The first line, "ready", says the handlers are in place.
"""
import ctypes
import os
import signal
import sys
import time

log, mode = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "catch")
try:   # the name pgrep -x and /proc/PID/comm match on
    ctypes.CDLL(None).prctl(15, b"waybar", 0, 0, 0)
except OSError:
    pass
out = open(log, "a", buffering=1)
if mode == "ignore":
    out.write("ready\n")
    while True:
        time.sleep(3600)
sigs = [signal.SIGRTMIN + n for n in range(8, 14)]
for s in sigs + [signal.SIGRTMAX]:
    signal.signal(s, lambda *_: None)   # a handler: the bit in SigCgt that kawa-dwlstatus checks
# blocked, then taken one by one: every queued delivery is counted, in order
signal.pthread_sigmask(signal.SIG_BLOCK, sigs + [signal.SIGRTMAX])
out.write("ready\n")
while True:
    info = signal.sigwaitinfo(sigs + [signal.SIGRTMAX])
    out.write("flush\n" if info.si_signo == signal.SIGRTMAX else f"{info.si_signo - signal.SIGRTMIN}\n")
