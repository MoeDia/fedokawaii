#!/usr/bin/env python3
"""tests/yazi/syncplay_ipc.py — the two fixes src/syncplay/syncplay.patch makes to the mpv
connection Syncplay carries (syncplay/vendor/python_mpv_jsonipc), tried on the copy installed:
a socket that exists a moment before anyone listens on it (mpv starting), and a player that
goes away while a command waits for its answer (mpv closed). No mpv needed: a plain socket
plays its part.

    python3 syncplay_ipc.py SYNCPLAY_DIR

SYNCPLAY_DIR is the folder the syncplay starter runs (its dir=). Prints "case TEXT", then
"ok" or "no WHY" per check, as syncplay_pair.py does.
"""
import os, shutil, socket, sys, tempfile, threading, time

sys.path.insert(0, sys.argv[1])
from syncplay.vendor.python_mpv_jsonipc import python_mpv_jsonipc as jsonipc


def case(text):
    print("case " + text, flush=True)


def check(ok, why=""):
    print("ok" if ok else "no " + str(why), flush=True)


tmp = tempfile.mkdtemp(prefix="kawa-ipc.")
held = []

case("Syncplay's player start: a socket there a moment before it listens (mpv starting) is waited for, not refused")
path = os.path.join(tmp, "starting")
srv = socket.socket(socket.AF_UNIX)
srv.bind(path)                                   # the file is there; nobody listens yet


def listen_later():
    time.sleep(0.6)
    srv.listen(1)
    conn, _ = srv.accept()
    held.append(conn)


threading.Thread(target=listen_later, daemon=True).start()
try:
    s = jsonipc.UnixSocket(path)
    check(True)
    s.stop(join=False)
except OSError as e:
    check(False, f"{type(e).__name__}: {e}")

case("Syncplay's player gone while a command waits (mpv closed): the wait ends at once, not after the timeout")
path = os.path.join(tmp, "closing")
srv2 = socket.socket(socket.AF_UNIX)
srv2.bind(path)
srv2.listen(1)


def answer_nothing():                            # reads the command, then closes, as mpv quitting
    conn, _ = srv2.accept()
    conn.recv(4096)
    time.sleep(0.2)
    conn.close()


threading.Thread(target=answer_nothing, daemon=True).start()
jsonipc.TIMEOUT = 6                              # (Syncplay's own is 120 s)
inter = jsonipc.MPVInter(path)
t0 = time.monotonic()
try:
    inter.command("quit")
except (TimeoutError, OSError, jsonipc.MPVError):
    pass
waited = time.monotonic() - t0
check(waited < 2, f"waited {waited:.1f} s for a player that was gone")
inter.stop(join=False)
for c in held:
    c.close()
shutil.rmtree(tmp, ignore_errors=True)
