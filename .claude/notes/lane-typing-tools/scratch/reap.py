#!/usr/bin/python3 -I
"""reap.py CMD…: CMD under a subreaper, so that what it orphans is reaped here and not left a zombie under a hung
service manager. Exits with CMD's status once CMD has ended and its orphans have too (or after 5 more seconds)."""
import ctypes
import os
import signal
import sys
import time

ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0)     # PR_SET_CHILD_SUBREAPER
pid = os.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
rc, gone_at = None, None
signal.signal(signal.SIGTERM, lambda *_: os.kill(pid, signal.SIGTERM))
while True:
    try:
        p, st = os.waitpid(-1, os.WNOHANG if rc is not None else 0)
    except ChildProcessError:
        break
    if p == pid:
        rc = os.waitstatus_to_exitcode(st)
        gone_at = time.monotonic()
    elif p == 0:
        if time.monotonic() - gone_at > 5:
            break
        time.sleep(0.05)
sys.exit(0 if rc is None else rc if rc >= 0 else 128 - rc)
