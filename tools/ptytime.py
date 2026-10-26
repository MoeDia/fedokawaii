#!/usr/bin/env python3
"""tools/ptytime.py — how long a terminal program takes to come up, in a real pseudo-terminal
(TERM=foot, a window's size): no compositor in the way, its own drawing only.

  python3 tools/ptytime.py [--runs N] [--size COLSxROWS] [--settle MS] [--timeout S] -- CMD…

Per run: ms to its first output, and ms until it exits by itself — or, with --settle, until it
has drawn nothing for MS ms (a screen that stays up: yazi, btop, lazygit), then it is sent
SIGTERM. Prints each run and the median; --json for the numbers.
Exit 0 · 1 a run timed out · 2 misuse.
"""
import json
import os
import pty
import select
import signal
import statistics
import struct
import sys
import termios
import fcntl
import time


def one(cmd, cols, rows, settle, timeout):
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["TERM"] = "foot"
        os.environ["COLUMNS"], os.environ["LINES"] = str(cols), str(rows)
        try:
            os.execvp(cmd[0], cmd)
        except OSError:
            os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    t0 = time.monotonic()
    first = last = None
    deadline = t0 + timeout
    done = timed_out = False
    while not done:
        now = time.monotonic()
        if now > deadline:
            timed_out = True
            break
        wait = 0.05
        if settle and last is not None:
            wait = max(0.0, min(wait, last + settle / 1000.0 - now))
            if wait == 0.0:
                break
        r, _, _ = select.select([fd], [], [], wait)
        if r:
            try:
                data = os.read(fd, 65536)
            except OSError:
                data = b""
            if not data:
                done = True
                break
            now = time.monotonic()
            if first is None:
                first = now
            last = now
            # (answer the terminal queries a TUI waits for: device attributes, cursor position)
            if b"\x1b[c" in data or b"\x1b[0c" in data:
                os.write(fd, b"\x1b[?62;22c")
            if b"\x1b[6n" in data:
                os.write(fd, b"\x1b[1;1R")
        else:
            if os.waitpid(pid, os.WNOHANG)[0]:
                done = True
                pid = None
    end = time.monotonic() if done else (last or time.monotonic())
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
        except (ProcessLookupError, ChildProcessError):
            pass
    os.close(fd)
    return {"first_ms": round(((first or end) - t0) * 1000, 1),
            "ready_ms": round(((last if settle else end) - t0) * 1000, 1), "timed_out": timed_out}


def main(argv):
    args = argv[1:]
    if "--" not in args or args[0] in ("-h", "--help"):
        print(__doc__.strip())
        return 0 if args and args[0] in ("-h", "--help") else 2
    k = args.index("--")
    opts, cmd = args[:k], args[k + 1:]
    def opt(name, default):
        return opts[opts.index(name) + 1] if name in opts else default
    runs = int(opt("--runs", "5"))
    cols, rows = (int(v) for v in opt("--size", "120x34").split("x"))
    settle = int(opt("--settle", "0"))
    timeout = float(opt("--timeout", "20"))
    res = [one(cmd, cols, rows, settle, timeout) for _ in range(runs)]
    med = {k: statistics.median(r[k] for r in res) for k in ("first_ms", "ready_ms")}
    if "--json" in opts:
        print(json.dumps({"runs": res, "median": med}))
    else:
        for r in res:
            print(f"first {r['first_ms']:8.1f} ms · {'ready' if settle else 'exit '} {r['ready_ms']:8.1f} ms{' · TIMED OUT' if r['timed_out'] else ''}")
        print(f"median: first {med['first_ms']} ms · {'ready' if settle else 'exit'} {med['ready_ms']} ms ({runs} runs)")
    return 1 if any(r["timed_out"] for r in res) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
