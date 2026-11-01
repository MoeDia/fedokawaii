#!/usr/bin/env python3
"""tools/kit-keys.py — a text screen driven by timed keys, drawn live in the terminal it runs in: for
the kit's tui scene (tools/kit.sh --tui), where a screen several keys deep (a list, then a choice, then
the file dialog) must be on the terminal when the shot is taken.

    python3 -I tools/kit-keys.py [SECONDS:KEYS]… -- CMD [ARG…]

CMD runs in a pseudo-terminal of this terminal's size; what it draws is passed through as it comes;
each KEYS (Python escapes: \\n, \\r, \\e …) is typed SECONDS after the start. Ends with CMD (its status),
or 60 s after the last key. Nothing is read from this terminal's own keyboard.
"""
import fcntl
import os
import pty
import select
import struct
import sys
import termios
import time
import tty


def main(argv):
    if '--' not in argv or argv.index('--') == len(argv) - 1:
        print(__doc__, file=sys.stderr)
        return 2
    cut = argv.index('--')
    keys = []
    for spec in argv[:cut]:
        at, _, text = spec.partition(':')
        keys.append((float(at), text.encode().decode('unicode_escape').encode()))
    keys.sort()
    cmd = argv[cut + 1:]
    size = fcntl.ioctl(1, termios.TIOCGWINSZ, b'\0' * 8) if os.isatty(1) else struct.pack('HHHH', 27, 100, 0, 0)
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, size)
    # (this terminal raw and silent: what it reports — focus in and out, keys — is never echoed
    # onto the screen being drawn; it is read and dropped)
    saved = termios.tcgetattr(0) if os.isatty(0) else None
    if saved:
        tty.setraw(0)
    try:
        return run(fd, pid, keys)
    finally:
        if saved:
            termios.tcsetattr(0, termios.TCSADRAIN, saved)


def run(fd, pid, keys):
    start = time.monotonic()
    end = start + (keys[-1][0] if keys else 0) + 60
    while time.monotonic() < end:
        now = time.monotonic() - start
        while keys and keys[0][0] <= now:
            os.write(fd, keys.pop(0)[1])
        ready, _, _ = select.select([fd, 0] if os.isatty(0) else [fd], [], [], 0.02)
        if 0 in ready:
            os.read(0, 4096)
        if fd in ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            os.write(1, data)
    _, status = os.waitpid(pid, 0)
    return os.waitstatus_to_exitcode(status)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
