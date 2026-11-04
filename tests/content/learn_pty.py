#!/usr/bin/env python3
"""learn_pty.py COLSxROWS [--arg A]… STEP… — kawa-learn in a terminal of its own, what it draws read back as a
screen would (cursor moves, erases, text by width; colours, titles and sixels passed over, sixels counted).
Each STEP: a key's text with backslash escapes (j, \\r, \\x1b[B …) · =COLSxROWS the window takes that size ·
!dump the screen, between lines "--- screen" · !wait S · !term a SIGTERM · !hup a SIGHUP · !walk KEY N the key N
times, at once · !fuzz SECONDS SEED
keys, mouse and sizes at random. At the end it presses nothing: without !term it closes with q, q, and its
exit status is the program's (124 still running after 5 s; 125 a Traceback in what it wrote)."""
import codecs
import fcntl
import os
import pty
import random
import re
import select
import signal
import struct
import sys
import termios
import time
import unicodedata

KEYS = ["j", "k", "h", "l", " ", "\r", "\t", "\x1b[Z", "\x1b", "g", "G", "s", "n", "p", "/", "b", "q", "x", "\x7f", "é", "京",
        "\x1b[A", "\x1b[B", "\x1b[C", "\x1b[D", "\x1b[5~", "\x1b[6~", "\x1b[H", "\x1b[F", "\x1bO", "\x1b[", "\x03"[:0], "\x15",
        "\x1b[<0;9;9M", "\x1b[<0;9;9m", "\x1b[<35;20;12M", "\x1b[<64;9;9M", "\x1b[<65;9;9M", "\x1b[?997;2n", "\xff".encode("latin1").decode("latin1")]


class Screen:
    def __init__(self, cols, rows):
        self.resize(cols, rows)
        self.x = self.y = 0
        self.sixels = 0
        self.inks = []
        self.buf = ""

    def resize(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.grid = [[" "] * cols for _ in range(rows)]

    def erase_line(self, y, x0=0):
        if 0 <= y < self.rows:
            for x in range(x0, self.cols):
                self.grid[y][x] = " "

    def put(self, c):
        if unicodedata.category(c) in ("Mn", "Me", "Cf"):
            return
        w = 2 if unicodedata.east_asian_width(c) in "WF" else 1
        if self.y < self.rows:
            if self.x + w > self.cols:
                print(f"past the edge: {c!r} at row {self.y}", file=sys.stderr)
                self.over = True
            elif self.x < self.cols:
                self.grid[self.y][self.x] = c
                if w == 2:
                    self.grid[self.y][self.x + 1] = ""
        self.x += w

    over = False

    def feed(self, s):
        s = self.buf + s
        self.buf = ""
        i = 0
        while i < len(s):
            c = s[i]
            if c != "\x1b":
                if c == "\r":
                    self.x = 0
                elif c == "\n":
                    self.y += 1
                elif c >= " ":
                    self.put(c)
                i += 1
                continue
            if i + 1 >= len(s):
                self.buf = s[i:]
                return
            if s[i + 1] == "[":
                m = re.compile(r"\x1b\[([0-9;?<]*)([A-Za-z~])").match(s, i)
                if not m:
                    self.buf = s[i:]
                    return
                a = [int(v) if v.isdigit() else 0 for v in m[1].split(";")]
                if m[2] == "H":
                    self.y, self.x = (a[0] or 1) - 1, ((a[1] if len(a) > 1 else 1) or 1) - 1
                elif m[2] == "K":
                    self.erase_line(self.y, self.x)
                elif m[2] == "J" and a[0] == 2:
                    self.resize(self.cols, self.rows)
                i = m.end()
            elif s[i + 1] in "]P":
                end = s.find("\x1b\\", i)
                if end < 0:
                    self.buf = s[i:]
                    return
                if s[i + 1] == "P":
                    self.sixels += 1
                    self.inks.extend(re.findall(r"#0;2;(\d+;\d+;\d+)", s[i:end]))
                i = end + 2
            else:
                i += 2

    def text(self):
        return "\n".join("".join(r).rstrip() for r in self.grid)


def main():
    size = sys.argv[1]
    args = sys.argv[2:]
    extra = []
    while args and args[0] == "--arg":
        extra.append(args[1])
        args = args[2:]
    cols, rows = map(int, size.split("x"))
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("kawa-learn", ["kawa-learn"] + extra)
    def winsize(c, r):
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", r, c, 0, 0))
        os.kill(pid, signal.SIGWINCH)
    winsize(cols, rows)
    scr = Screen(cols, rows)
    all_out = []
    dec = codecs.getincrementaldecoder("utf-8")("replace")
    def pump(quiet=0.05, most=1.0):
        end = time.monotonic() + most
        while time.monotonic() < end:
            r, _, _ = select.select([fd], [], [], quiet)
            if not r:
                return
            try:
                d = os.read(fd, 65536)
            except OSError:
                return
            if not d:
                return
            s = dec.decode(d)
            all_out.append(s)
            scr.feed(s)
    def send(b):
        try:
            os.write(fd, b)
        except OSError:
            pass
    pump(0.3, 3.0)
    i = 0
    term_sent = False
    while i < len(args):
        st = args[i]
        i += 1
        if st == "!dump":
            print("--- screen")
            print(scr.text())
        elif st == "!wait":
            time.sleep(float(args[i]))
            i += 1
            pump()
        elif st in ("!term", "!hup"):
            os.kill(pid, signal.SIGTERM if st == "!term" else signal.SIGHUP)
            term_sent = True
            pump(0.2, 1.0)
        elif st == "!walk":             # (a key pressed N times, as fast as it takes it)
            k, n = codecs.decode(args[i], "unicode_escape").encode(), int(args[i + 1])
            i += 2
            for _ in range(n):
                send(k)
                pump(0.003, 0.05)
            pump(0.3, 3.0)
        elif st == "!fuzz":
            secs, seed = float(args[i]), int(args[i + 1])
            i += 2
            rnd = random.Random(seed)
            end = time.monotonic() + secs
            while time.monotonic() < end:
                if rnd.random() < 0.05:
                    cols, rows = rnd.randint(1, 240), rnd.randint(1, 70)
                    scr.resize(cols, rows)
                    winsize(cols, rows)
                else:
                    k = rnd.choice(KEYS)
                    if k != "q" and k != "\x1b":
                        send(k.encode("utf-8", "replace"))
                    elif rnd.random() < 0.2:        # (a way out is a key too: back in at once when it was the last)
                        send(k.encode())
                pump(0.002, 0.02)
                done, _ = os.waitpid(pid, os.WNOHANG)
                if done:
                    joined = "".join(all_out)
                    print("Traceback" in joined and joined[joined.index("Traceback"):] or "it ended", file=sys.stderr)
                    return 125 if "Traceback" in joined else 0
        elif st.startswith("="):
            cols, rows = map(int, st[1:].split("x"))
            scr.resize(cols, rows)
            winsize(cols, rows)
            pump(0.2)
        else:
            send(codecs.decode(st, "unicode_escape").encode("latin1").decode("utf-8", "replace").encode())
            pump(0.25, 3.0)     # (quiet for a moment: a busy machine, a lesson unrolling)
    if not term_sent:
        send(b"q")
        pump(0.1)
        send(b"q")
        pump(0.1)
    end = time.monotonic() + 5
    status = None
    while time.monotonic() < end:
        done, st = os.waitpid(pid, os.WNOHANG)
        if done:
            status = st
            break
        pump(0.05, 0.1)
    pump(0.05, 0.2)
    joined = "".join(all_out)
    if "Traceback" in joined:
        print(joined[joined.index("Traceback"):], file=sys.stderr)
        return 125
    if status is None:
        os.kill(pid, signal.SIGKILL)
        return 124
    print(f"--- sixels {scr.sixels} {' '.join(scr.inks)}")
    return os.waitstatus_to_exitcode(status)


if __name__ == "__main__":
    sys.exit(main())
