#!/usr/bin/env python3
"""pty_run.py [--cols N] [--rows N] [--answer QUERY REPLY] [--delay S] [--send AT TEXT] [--hangup AT] [--timeout S] -- CMD…

CMD in a terminal of its own (a pseudo-terminal that is its controlling tty, so /dev/tty,
stty and bash's checkwinsize all work), the size given. What CMD writes is copied to stdout
as is; the exit status is CMD's (124 when it ran past --timeout and was killed).

--send AT TEXT: types TEXT (backslash escapes) AT seconds after the start. --hangup AT: the
terminal goes away AT seconds after the start (as when its window is closed): the pty's
master is closed, CMD gets SIGHUP; what it wrote until then is copied out. --hangup +S: S
seconds after the first --answer was typed.

--answer: plays the terminal's part in a query — whenever QUERY (backslash escapes, e.g.
'\\x1b[16t') first appears in what CMD writes, REPLY is typed back after --delay seconds.
Several --answer pairs may be given; each is answered once.
"""
import os, pty, select, signal, struct, sys, termios, fcntl, time


def unescape(s):
    return s.encode("latin1").decode("unicode_escape").encode("latin1")


def main(argv):
    cols, rows, delay, timeout, answers, sends, hangup = 80, 24, 0.0, 20.0, [], [], None
    i = 0
    while i < len(argv) and argv[i] != "--":
        a = argv[i]
        if a == "--cols": cols = int(argv[i + 1]); i += 2
        elif a == "--rows": rows = int(argv[i + 1]); i += 2
        elif a == "--delay": delay = float(argv[i + 1]); i += 2
        elif a == "--timeout": timeout = float(argv[i + 1]); i += 2
        elif a == "--answer": answers.append((unescape(argv[i + 1]), unescape(argv[i + 2]))); i += 3
        elif a == "--send": sends.append((float(argv[i + 1]), unescape(argv[i + 2]))); i += 3
        elif a == "--hangup": hangup = argv[i + 1]; i += 2
        else: sys.exit(f"pty_run: unknown option {a}")
    cmd = argv[i + 1:]
    if not cmd: sys.exit("pty_run: no command")
    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            os.write(2, f"pty_run: {e}\n".encode()); os._exit(127)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
    start = time.monotonic()
    out, seen, end = bytearray(), 0, start + timeout
    pending = [(start + at, text) for at, text in sends]   # (when, what to type)
    answered, done = None, set()
    if hangup is not None and not hangup.startswith("+"): hangup = start + float(hangup)
    status = None
    while True:
        now = time.monotonic()
        for p in [p for p in pending if p[0] <= now]:
            os.write(fd, p[1]); pending.remove(p)
            if answered is None and p[2:] == ("answer",): answered = now
        if now > end:
            os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0); status = 124; break
        if isinstance(hangup, str) and answered is not None: hangup = answered + float(hangup[1:])
        if isinstance(hangup, float) and now >= hangup:
            os.close(fd)
            for _ in range(200):                     # (10 s at most to go)
                p, st = os.waitpid(pid, os.WNOHANG)
                if p: break
                time.sleep(0.05)
            else:
                os.kill(pid, signal.SIGKILL); p, st = os.waitpid(pid, 0)
            status = os.waitstatus_to_exitcode(st)
            status = status if status >= 0 else 128 - status
            break
        r, _, _ = select.select([fd], [], [], 0.02)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                chunk = b""
            if not chunk:
                break
            out += chunk
            for q, reply in answers:                 # each new appearance of a query
                start = max(0, seen - len(q) + 1)
                if q in done: continue
                if out.find(q, start) >= 0:
                    pending.append((time.monotonic() + delay, reply, "answer")); done.add(q)
            seen = len(out)
    if status is None:
        _, st = os.waitpid(pid, 0)
        status = os.waitstatus_to_exitcode(st)
        status = status if status >= 0 else 128 - status
    sys.stdout.buffer.write(bytes(out))
    sys.exit(status)


if __name__ == "__main__":
    main(sys.argv[1:])
